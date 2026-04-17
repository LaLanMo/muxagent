// Package gitstatus reads git working-tree status for a checkout.
//
// It is a pure library: no RPC types leak in, no logging. Two callers
// (the stdio app-server and the relay websocket daemon) translate the
// returned struct into their own wire DTOs.
package gitstatus

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"os/exec"
	"sort"
	"strings"
	"time"
)

// Mode controls how much work Snapshot does.
type Mode int

const (
	// ModeSummaryOnly returns counts + branch + head but does not list files.
	// Uses --untracked-files=normal so large untracked dirs are not recursed.
	ModeSummaryOnly Mode = iota
	// ModeWithFiles returns counts + branch + head + a page of Files.
	// Uses --untracked-files=all.
	ModeWithFiles
)

// FileBucket classifies a FileChange.
type FileBucket string

const (
	BucketStaged     FileBucket = "staged"
	BucketUnstaged   FileBucket = "unstaged"
	BucketUntracked  FileBucket = "untracked"
	BucketConflicted FileBucket = "conflicted"
)

const (
	// DefaultFileLimit is the default page size when FileLimit <= 0.
	DefaultFileLimit = 200
	// MaxFileLimit caps explicit FileLimit values.
	MaxFileLimit = 1000
	// maxPorcelainBytes is the upper bound on raw git status output we will read.
	maxPorcelainBytes = 16 * 1024 * 1024
	// maxStderrBytes is the upper bound on captured stderr per child process.
	maxStderrBytes = 8 * 1024

	// snapshotDefaultTimeout is the wall-clock budget inside Snapshot.
	snapshotDefaultTimeout = 10 * time.Second
	// listWorktreesTimeout bounds a `git worktree list --porcelain` call.
	listWorktreesTimeout = 10 * time.Second
)

// Unreachable reason codes reported when git cannot read the checkout.
const (
	ReasonNotAGitRepo  = "not_a_git_repo"
	ReasonPathMissing  = "path_missing"
	ReasonSafeDir      = "safe_directory"
	ReasonTimeout      = "timeout"
	ReasonInternal     = "internal"
	ReasonOutputTooBig = "output_too_big"
)

// SnapshotOpts controls Snapshot behavior.
type SnapshotOpts struct {
	Mode Mode
	// FileCursor is opaque; decode failures are treated as an empty cursor.
	FileCursor string
	// FileLimit caps the number of Files returned. 0 means DefaultFileLimit.
	FileLimit int
}

// FileChange is one changed path in a checkout.
type FileChange struct {
	Path     string
	OrigPath string // filled on rename/copy; otherwise empty
	XY       string // two-character porcelain v2 status code
	Bucket   FileBucket
}

// CheckoutStatus is the full result for one checkout path.
type CheckoutStatus struct {
	Reachable         bool
	UnreachableReason string // one of the Reason* constants; empty when Reachable

	Branch         string
	DetachedHead   bool
	Upstream       string
	AheadCount     int
	BehindCount    int
	HeadCommit     string
	HeadSubject    string
	HeadAuthoredAt *time.Time

	StagedCount     int
	UnstagedCount   int
	UntrackedCount  int
	ConflictedCount int

	// Files is populated only when Mode == ModeWithFiles. It contains the page
	// starting after FileCursor (exclusive) and up to FileLimit entries.
	Files []FileChange
	// FilesTotal is the full count across all buckets (independent of the page).
	FilesTotal int
	// NextFileCursor is "" when the page is the last one.
	NextFileCursor string
}

// WorktreeEntry is one row from `git worktree list --porcelain`.
type WorktreeEntry struct {
	Path     string
	Head     string
	Branch   string // short ref (e.g. "main"); "" if detached
	Detached bool
	Locked   bool
	Prunable bool
}

// FindRepoRoot returns the git repository top-level for cwd, or an error if
// cwd is not inside a repo.
func FindRepoRoot(ctx context.Context, cwd string) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, listWorktreesTimeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, "git", "-C", cwd, "rev-parse", "--show-toplevel")
	cmd.Env = sanitizedEnv()
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("git rev-parse --show-toplevel in %q: %w: %s", cwd, err, strings.TrimSpace(stderr.String()))
	}
	return strings.TrimSpace(stdout.String()), nil
}

// Snapshot reads the git status of one checkout path.
//
// It never returns a non-nil error in practice; instead it returns a
// CheckoutStatus with Reachable=false and a populated UnreachableReason,
// so callers can present partial results when some worktrees fail.
func Snapshot(ctx context.Context, checkoutPath string, opts SnapshotOpts) (CheckoutStatus, error) {
	if opts.FileLimit <= 0 {
		opts.FileLimit = DefaultFileLimit
	}
	if opts.FileLimit > MaxFileLimit {
		opts.FileLimit = MaxFileLimit
	}

	ctx, cancel := context.WithTimeout(ctx, snapshotDefaultTimeout)
	defer cancel()

	raw, reason, err := runStatus(ctx, checkoutPath, opts.Mode)
	if reason != "" {
		return CheckoutStatus{Reachable: false, UnreachableReason: reason}, nil
	}
	if err != nil {
		return CheckoutStatus{Reachable: false, UnreachableReason: ReasonInternal}, nil
	}

	parsed, perr := parsePorcelainV2(raw)
	if perr != nil {
		return CheckoutStatus{Reachable: false, UnreachableReason: ReasonInternal}, nil
	}

	status := CheckoutStatus{
		Reachable:       true,
		Branch:          parsed.Branch,
		DetachedHead:    parsed.Detached,
		Upstream:        parsed.Upstream,
		AheadCount:      parsed.Ahead,
		BehindCount:     parsed.Behind,
		HeadCommit:      parsed.Head,
		StagedCount:     len(parsed.Staged),
		UnstagedCount:   len(parsed.Unstaged),
		UntrackedCount:  len(parsed.Untracked),
		ConflictedCount: len(parsed.Conflicted),
	}
	status.FilesTotal = status.StagedCount + status.UnstagedCount + status.UntrackedCount + status.ConflictedCount

	// HEAD subject + authored time are best-effort; unborn HEAD simply produces empty fields.
	if status.HeadCommit != "" && status.HeadCommit != unbornHeadSentinel {
		subject, authoredAt, ok := headMetadata(ctx, checkoutPath, status.HeadCommit)
		if ok {
			status.HeadSubject = subject
			if !authoredAt.IsZero() {
				t := authoredAt
				status.HeadAuthoredAt = &t
			}
		}
	}
	// Treat the v2 "initial commit" sentinel as unborn.
	if status.HeadCommit == unbornHeadSentinel {
		status.HeadCommit = ""
	}

	if opts.Mode == ModeWithFiles {
		sort.Slice(parsed.Staged, func(i, j int) bool { return parsed.Staged[i].Path < parsed.Staged[j].Path })
		sort.Slice(parsed.Unstaged, func(i, j int) bool { return parsed.Unstaged[i].Path < parsed.Unstaged[j].Path })
		sort.Slice(parsed.Untracked, func(i, j int) bool { return parsed.Untracked[i].Path < parsed.Untracked[j].Path })
		sort.Slice(parsed.Conflicted, func(i, j int) bool { return parsed.Conflicted[i].Path < parsed.Conflicted[j].Path })

		files, next := paginateFiles(parsed, opts.FileCursor, opts.FileLimit)
		status.Files = files
		status.NextFileCursor = next
	}

	return status, nil
}

// ListWorktrees enumerates `git worktree list --porcelain` rows for repoRoot.
func ListWorktrees(ctx context.Context, repoRoot string) ([]WorktreeEntry, error) {
	ctx, cancel := context.WithTimeout(ctx, listWorktreesTimeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, "git", "-C", repoRoot, "worktree", "list", "--porcelain")
	cmd.Env = sanitizedEnv()
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("git worktree list: %w: %s", err, strings.TrimSpace(stderr.String()))
	}
	return parseWorktreePorcelain(stdout.Bytes()), nil
}

// runStatus runs `git status --porcelain=v2 --branch -z`. It returns either
// raw bytes + "" + nil (ok), or "" + reason + nil when the error is a known
// reachability condition, or "" + "" + err for unexpected errors.
func runStatus(ctx context.Context, checkoutPath string, mode Mode) ([]byte, string, error) {
	untracked := "--untracked-files=all"
	if mode == ModeSummaryOnly {
		untracked = "--untracked-files=normal"
	}
	args := []string{
		"-c", "core.hooksPath=/dev/null",
		"-c", "gc.auto=0",
		"-c", "advice.detachedHead=false",
		"-C", checkoutPath,
		"status", "--porcelain=v2", "--branch", "-z",
		untracked,
		"--ignored=no",
		"--no-renames",
	}
	cmd := exec.CommandContext(ctx, "git", args...)
	cmd.Env = sanitizedEnv()

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, ReasonInternal, nil
	}
	var stderr bytes.Buffer
	cmd.Stderr = limitedWriter{w: &stderr, max: maxStderrBytes}

	if err := cmd.Start(); err != nil {
		return nil, ReasonInternal, nil
	}

	// Read stdout with a hard cap.
	raw, readErr := readAllWithLimit(stdout, maxPorcelainBytes)
	waitErr := cmd.Wait()

	if ctx.Err() == context.DeadlineExceeded {
		return nil, ReasonTimeout, nil
	}
	if readErr != nil {
		if errors.Is(readErr, errOutputTooBig) {
			return nil, ReasonOutputTooBig, nil
		}
		return nil, ReasonInternal, nil
	}
	if waitErr != nil {
		return nil, classifyStatusErr(stderr.String(), checkoutPath), nil
	}
	return raw, "", nil
}

// headMetadata runs `git log -1 --format=%s%x00%aI <commit>`.
func headMetadata(ctx context.Context, checkoutPath, commit string) (string, time.Time, bool) {
	cmd := exec.CommandContext(ctx, "git",
		"-c", "core.hooksPath=/dev/null",
		"-C", checkoutPath,
		"log", "-1", "--format=%s%x00%aI", commit,
	)
	cmd.Env = sanitizedEnv()
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = limitedWriter{w: &stderr, max: maxStderrBytes}
	if err := cmd.Run(); err != nil {
		return "", time.Time{}, false
	}
	out := strings.TrimRight(stdout.String(), "\n")
	parts := strings.SplitN(out, "\x00", 2)
	if len(parts) < 2 {
		return out, time.Time{}, true
	}
	subject := parts[0]
	ts, perr := time.Parse(time.RFC3339, parts[1])
	if perr != nil {
		return subject, time.Time{}, true
	}
	return subject, ts, true
}

// classifyStatusErr maps a failed `git status` stderr to one of the Reason* codes.
func classifyStatusErr(stderr, path string) string {
	s := strings.ToLower(stderr)
	switch {
	case strings.Contains(s, "not a git repository"):
		return ReasonNotAGitRepo
	case strings.Contains(s, "no such file or directory"),
		strings.Contains(s, "cannot chdir"):
		return ReasonPathMissing
	case strings.Contains(s, "dubious ownership"),
		strings.Contains(s, "safe.directory"):
		return ReasonSafeDir
	}
	_ = path
	return ReasonInternal
}

// errOutputTooBig is a sentinel returned by readAllWithLimit.
var errOutputTooBig = errors.New("git output exceeded limit")

func readAllWithLimit(r io.Reader, max int) ([]byte, error) {
	buf := make([]byte, 0, 64*1024)
	tmp := make([]byte, 32*1024)
	for {
		n, err := r.Read(tmp)
		if n > 0 {
			if len(buf)+n > max {
				// Drain to allow the child to exit cleanly, but cap what we keep.
				for {
					_, derr := r.Read(tmp)
					if derr != nil {
						break
					}
				}
				return nil, errOutputTooBig
			}
			buf = append(buf, tmp[:n]...)
		}
		if err != nil {
			if errors.Is(err, io.EOF) {
				return buf, nil
			}
			return nil, err
		}
	}
}

type limitedWriter struct {
	w   io.Writer
	max int
	n   int
}

func (lw limitedWriter) Write(p []byte) (int, error) {
	if lw.n >= lw.max {
		return len(p), nil
	}
	if lw.n+len(p) > lw.max {
		p = p[:lw.max-lw.n]
	}
	return lw.w.Write(p)
}
