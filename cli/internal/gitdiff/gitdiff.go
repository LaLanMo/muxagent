// Package gitdiff reads git diffs (file + commit) for a checkout.
//
// It is a pure library: no RPC types leak in, no logging. Callers (the
// stdio app-server and the relay websocket daemon) translate the
// returned struct into their own wire DTOs.
package gitdiff

import (
	"bytes"
	"context"
	"errors"
	"io"
	"os"
	"os/exec"
	"strings"
	"time"
)

// FileBucket classifies which diff command to run for a file path.
type FileBucket string

const (
	BucketStaged     FileBucket = "staged"
	BucketUnstaged   FileBucket = "unstaged"
	BucketUntracked  FileBucket = "untracked"
	BucketConflicted FileBucket = "conflicted"
)

const (
	// DefaultMaxPatchBytes caps the patch text returned.
	DefaultMaxPatchBytes = 2 * 1024 * 1024
	// MaxStderrBytes is the upper bound on captured stderr per child.
	maxStderrBytes = 8 * 1024
	// DefaultTimeout is the wall-clock budget for a single diff call.
	DefaultTimeout = 10 * time.Second
)

// Unreachable reason codes mirrored from gitstatus so callers can reuse handling.
const (
	ReasonNotAGitRepo  = "not_a_git_repo"
	ReasonPathMissing  = "path_missing"
	ReasonTimeout      = "timeout"
	ReasonInternal     = "internal"
	ReasonOutputTooBig = "output_too_big"
	ReasonUnknownRev   = "unknown_revision"
	ReasonUnknownFile  = "unknown_file"
)

// Patch is the result of a file or commit diff.
type Patch struct {
	Reachable         bool
	UnreachableReason string
	Patch             string
	Truncated         bool
	Binary            bool
	// FileCount is meaningful for commit diffs; 1 for file diffs.
	FileCount int
	// Subject / AuthoredAt filled for commit diffs.
	Subject    string
	Author     string
	AuthorMail string
	AuthoredAt *time.Time
	Hash       string
}

// FileDiffOpts controls the file diff call.
type FileDiffOpts struct {
	Bucket        FileBucket
	MaxPatchBytes int
}

// CommitDiffOpts controls the commit diff call.
type CommitDiffOpts struct {
	MaxPatchBytes int
}

// FileDiff runs the appropriate `git diff` invocation for the file bucket.
func FileDiff(ctx context.Context, checkoutPath, filePath string, opts FileDiffOpts) (Patch, error) {
	maxBytes := opts.MaxPatchBytes
	if maxBytes <= 0 {
		maxBytes = DefaultMaxPatchBytes
	}
	ctx, cancel := context.WithTimeout(ctx, DefaultTimeout)
	defer cancel()

	if filePath == "" {
		return Patch{Reachable: false, UnreachableReason: ReasonUnknownFile}, nil
	}

	switch opts.Bucket {
	case BucketStaged:
		raw, reason, trunc := runGit(ctx, checkoutPath, maxBytes,
			"diff", "--cached", "--no-color", "--", filePath)
		return finalizeFilePatch(raw, reason, trunc, filePath), nil

	case BucketUnstaged, BucketConflicted, "":
		raw, reason, trunc := runGit(ctx, checkoutPath, maxBytes,
			"diff", "--no-color", "--", filePath)
		return finalizeFilePatch(raw, reason, trunc, filePath), nil

	case BucketUntracked:
		return untrackedFilePatch(ctx, checkoutPath, filePath, maxBytes), nil
	}

	return Patch{Reachable: false, UnreachableReason: ReasonInternal}, nil
}

// CommitDiff runs `git show --stat --patch --no-color <hash>`.
func CommitDiff(ctx context.Context, checkoutPath, hash string, opts CommitDiffOpts) (Patch, error) {
	maxBytes := opts.MaxPatchBytes
	if maxBytes <= 0 {
		maxBytes = DefaultMaxPatchBytes
	}
	hash = strings.TrimSpace(hash)
	if hash == "" {
		return Patch{Reachable: false, UnreachableReason: ReasonUnknownRev}, nil
	}

	ctx, cancel := context.WithTimeout(ctx, DefaultTimeout)
	defer cancel()

	metaRaw, metaReason, _ := runGit(ctx, checkoutPath, 4096,
		"show", "-s", "--no-color", "--format=%H%x00%s%x00%an%x00%ae%x00%aI", hash)
	if metaReason != "" {
		return Patch{Reachable: false, UnreachableReason: metaReason}, nil
	}

	patchRaw, patchReason, trunc := runGit(ctx, checkoutPath, maxBytes,
		"show", "--no-color", "--stat", "--patch", "--format=", hash)
	if patchReason != "" {
		return Patch{Reachable: false, UnreachableReason: patchReason}, nil
	}

	full, hash2, subject, author, authorMail, authored := parseCommitMeta(string(metaRaw))
	if hash2 == "" {
		hash2 = hash
	}
	_ = full

	patchText, binary := sanitizePatch(string(patchRaw))
	fileCount := countFilesInPatch(patchText)

	p := Patch{
		Reachable:  true,
		Patch:      patchText,
		Truncated:  trunc,
		Binary:     binary,
		FileCount:  fileCount,
		Subject:    subject,
		Author:     author,
		AuthorMail: authorMail,
		Hash:       hash2,
	}
	if authored != nil {
		p.AuthoredAt = authored
	}
	return p, nil
}

func runGit(ctx context.Context, cwd string, maxBytes int, args ...string) ([]byte, string, bool) {
	fullArgs := append([]string{
		"-c", "core.hooksPath=/dev/null",
		"-c", "gc.auto=0",
		"-c", "advice.detachedHead=false",
		"-C", cwd,
	}, args...)

	cmd := exec.CommandContext(ctx, "git", fullArgs...)
	cmd.Env = sanitizedEnv()

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, ReasonInternal, false
	}
	var stderr bytes.Buffer
	cmd.Stderr = limitedWriter{w: &stderr, max: maxStderrBytes}
	if err := cmd.Start(); err != nil {
		return nil, ReasonInternal, false
	}

	buf, readErr := readWithLimit(stdout, maxBytes)
	waitErr := cmd.Wait()

	if ctx.Err() == context.DeadlineExceeded {
		return nil, ReasonTimeout, false
	}
	truncated := errors.Is(readErr, errOutputTooBig)
	if readErr != nil && !truncated {
		return nil, ReasonInternal, false
	}
	if waitErr != nil && !truncated {
		return nil, classifyStderr(stderr.String()), false
	}
	return buf, "", truncated
}

func finalizeFilePatch(raw []byte, reason string, truncated bool, filePath string) Patch {
	if reason != "" {
		return Patch{Reachable: false, UnreachableReason: reason}
	}
	patchText, binary := sanitizePatch(string(raw))
	return Patch{
		Reachable: true,
		Patch:     patchText,
		Truncated: truncated,
		Binary:    binary,
		FileCount: 1,
	}
}

// untrackedFilePatch synthesizes a "new file" patch for an untracked path by
// reading the file directly. Binary files return Binary=true with no body.
func untrackedFilePatch(ctx context.Context, checkoutPath, filePath string, maxBytes int) Patch {
	full := filePath
	if !strings.HasPrefix(full, "/") {
		full = strings.TrimRight(checkoutPath, "/") + "/" + filePath
	}
	info, err := os.Stat(full)
	if err != nil {
		return Patch{Reachable: false, UnreachableReason: ReasonUnknownFile}
	}
	if info.IsDir() {
		return Patch{Reachable: false, UnreachableReason: ReasonUnknownFile}
	}
	f, err := os.Open(full)
	if err != nil {
		return Patch{Reachable: false, UnreachableReason: ReasonInternal}
	}
	defer f.Close()

	buf, readErr := readWithLimit(f, maxBytes)
	truncated := errors.Is(readErr, errOutputTooBig)
	if readErr != nil && !truncated {
		return Patch{Reachable: false, UnreachableReason: ReasonInternal}
	}
	if looksBinary(buf) {
		return Patch{
			Reachable: true,
			Patch:     "diff --git a/" + filePath + " b/" + filePath + "\nnew file\nBinary files differ\n",
			Binary:    true,
			FileCount: 1,
			Truncated: truncated,
		}
	}
	body := string(buf)
	lines := strings.Split(strings.TrimRight(body, "\n"), "\n")
	var out strings.Builder
	out.WriteString("diff --git a/" + filePath + " b/" + filePath + "\n")
	out.WriteString("new file mode 100644\n")
	out.WriteString("--- /dev/null\n")
	out.WriteString("+++ b/" + filePath + "\n")
	out.WriteString("@@ -0,0 +1," + itoa(len(lines)) + " @@\n")
	for _, line := range lines {
		out.WriteString("+" + line + "\n")
	}
	return Patch{
		Reachable: true,
		Patch:     out.String(),
		Truncated: truncated,
		FileCount: 1,
	}
}

func sanitizePatch(s string) (string, bool) {
	binary := strings.Contains(s, "Binary files ")
	return s, binary
}

func countFilesInPatch(patch string) int {
	n := 0
	for _, line := range strings.Split(patch, "\n") {
		if strings.HasPrefix(line, "diff --git ") {
			n++
		}
	}
	if n == 0 && patch != "" {
		return 1
	}
	return n
}

func parseCommitMeta(raw string) (full, hash, subject, author, mail string, authored *time.Time) {
	raw = strings.TrimRight(raw, "\n")
	parts := strings.Split(raw, "\x00")
	if len(parts) >= 1 {
		hash = strings.TrimSpace(parts[0])
	}
	if len(parts) >= 2 {
		subject = parts[1]
	}
	if len(parts) >= 3 {
		author = parts[2]
	}
	if len(parts) >= 4 {
		mail = parts[3]
	}
	if len(parts) >= 5 {
		if ts, err := time.Parse(time.RFC3339, strings.TrimSpace(parts[4])); err == nil {
			authored = &ts
		}
	}
	return "", hash, subject, author, mail, authored
}

func classifyStderr(stderr string) string {
	s := strings.ToLower(stderr)
	switch {
	case strings.Contains(s, "not a git repository"):
		return ReasonNotAGitRepo
	case strings.Contains(s, "unknown revision"),
		strings.Contains(s, "bad revision"),
		strings.Contains(s, "bad object"),
		strings.Contains(s, "ambiguous argument"):
		return ReasonUnknownRev
	case strings.Contains(s, "no such file"),
		strings.Contains(s, "path is not in the working tree"),
		strings.Contains(s, "pathspec"):
		return ReasonUnknownFile
	case strings.Contains(s, "cannot chdir"):
		return ReasonPathMissing
	}
	return ReasonInternal
}

var errOutputTooBig = errors.New("git output exceeded limit")

func readWithLimit(r io.Reader, max int) ([]byte, error) {
	buf := make([]byte, 0, 64*1024)
	tmp := make([]byte, 32*1024)
	for {
		n, err := r.Read(tmp)
		if n > 0 {
			if len(buf)+n > max {
				keep := max - len(buf)
				if keep > 0 {
					buf = append(buf, tmp[:keep]...)
				}
				for {
					_, derr := r.Read(tmp)
					if derr != nil {
						break
					}
				}
				return buf, errOutputTooBig
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

func looksBinary(b []byte) bool {
	n := len(b)
	if n > 4096 {
		n = 4096
	}
	for i := 0; i < n; i++ {
		if b[i] == 0 {
			return true
		}
	}
	return false
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	neg := n < 0
	if neg {
		n = -n
	}
	buf := [20]byte{}
	i := len(buf)
	for n > 0 {
		i--
		buf[i] = byte('0' + n%10)
		n /= 10
	}
	if neg {
		i--
		buf[i] = '-'
	}
	return string(buf[i:])
}

// sanitizedEnv returns a minimal environment for a git child process.
// It strips GIT_* variables inherited from the parent and sets defaults
// so git does not prompt or take locks.
func sanitizedEnv() []string {
	parent := os.Environ()
	out := make([]string, 0, len(parent)+4)
	for _, kv := range parent {
		key, _, ok := strings.Cut(kv, "=")
		if !ok {
			out = append(out, kv)
			continue
		}
		if strings.HasPrefix(key, "GIT_") {
			continue
		}
		out = append(out, kv)
	}
	out = append(out,
		"GIT_ASKPASS=/bin/true",
		"GIT_TERMINAL_PROMPT=0",
		"GIT_OPTIONAL_LOCKS=0",
		"LANG=C",
	)
	return out
}
