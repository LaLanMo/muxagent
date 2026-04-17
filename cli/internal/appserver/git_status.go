package appserver

import (
	"context"
	"crypto/sha256"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/LaLanMo/muxagent/cli/internal/gitstatus"
	"golang.org/x/sync/errgroup"
)

const (
	worktreeListHardCap = 200
	perCheckoutCeiling  = 4
)

// buildWorkspaceGitStatus enumerates main + worktrees and returns a summary
// for each. Per-checkout failures are folded into the DTO as Reachable=false,
// so the RPC as a whole only errors on truly unexpected problems.
func buildWorkspaceGitStatus(ctx context.Context, workspace workspaceRecord, now func() time.Time) (workspaceGitStatusResult, error) {
	if now == nil {
		now = time.Now
	}
	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	result := workspaceGitStatusResult{
		Main:        gitCheckoutSummaryDTO{Role: gitCheckoutRoleMain, Path: workspace.Path},
		Worktrees:   []gitCheckoutSummaryDTO{},
		CollectedAt: now().UTC(),
	}

	mainCanonical, mainResolveErr := canonicalExistingPath(workspace.Path)

	repoRoot, err := gitstatus.FindRepoRoot(ctx, workspace.Path)
	if err != nil {
		result.Main.Reachable = false
		result.Main.UnreachableReason = gitstatus.ReasonNotAGitRepo
		if mainResolveErr != nil || !pathExists(workspace.Path) {
			result.Main.UnreachableReason = gitstatus.ReasonPathMissing
		}
		return result, nil
	}

	entries, _ := gitstatus.ListWorktrees(ctx, repoRoot)
	filtered := make([]gitstatus.WorktreeEntry, 0, len(entries))
	for _, e := range entries {
		canonicalEntry, _ := canonicalExistingPath(e.Path)
		if canonicalEntry != "" && mainCanonical != "" && canonicalEntry == mainCanonical {
			continue
		}
		filtered = append(filtered, e)
	}

	total := len(filtered)
	truncated := false
	if total > worktreeListHardCap {
		filtered = filtered[:worktreeListHardCap]
		truncated = true
	}
	result.WorktreesTotalCount = total
	result.WorktreesTruncated = truncated

	homeDir, _ := os.UserHomeDir()
	repoHash := repoHashForRoot(repoRoot)

	// Main snapshot plus one per worktree, concurrency capped.
	g, gctx := errgroup.WithContext(ctx)
	g.SetLimit(perCheckoutCeiling)

	var (
		mainSummary gitCheckoutSummaryDTO
		wtSummaries = make([]gitCheckoutSummaryDTO, len(filtered))
	)

	g.Go(func() error {
		snap, _ := gitstatus.Snapshot(gctx, workspace.Path, gitstatus.SnapshotOpts{Mode: gitstatus.ModeSummaryOnly})
		mainSummary = snapshotToSummaryDTO(snap, workspace.Path, gitCheckoutRoleMain, gitstatus.WorktreeEntry{})
		return nil
	})
	for i := range filtered {
		i := i
		entry := filtered[i]
		g.Go(func() error {
			snap, _ := gitstatus.Snapshot(gctx, entry.Path, gitstatus.SnapshotOpts{Mode: gitstatus.ModeSummaryOnly})
			role := classifyRole(entry.Path, homeDir, repoHash)
			summary := snapshotToSummaryDTO(snap, entry.Path, role, entry)
			wtSummaries[i] = summary
			return nil
		})
	}
	_ = g.Wait()

	result.Main = mainSummary
	// Preserve the main reachability path semantics: if repo root was found we
	// know the main checkout is a repo, so if Snapshot happened to report a
	// missing path (raced rm -rf), we leave that as-is.
	result.Worktrees = wtSummaries

	sort.Slice(result.Worktrees, func(i, j int) bool {
		return result.Worktrees[i].Path < result.Worktrees[j].Path
	})
	return result, nil
}

// buildCheckoutStatus returns a detailed status for a single checkout,
// validating that it belongs to the requested workspace before running git.
func buildCheckoutStatus(ctx context.Context, workspace workspaceRecord, checkoutPath, fileCursor string, fileLimit int, now func() time.Time) (workspaceCheckoutStatusResult, *rpcError) {
	if now == nil {
		now = time.Now
	}
	checkoutPath = strings.TrimSpace(checkoutPath)
	if checkoutPath == "" {
		return workspaceCheckoutStatusResult{}, &rpcError{Code: errorCodeInvalidParams, Message: "checkout_path is required"}
	}

	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	role, ok := validateCheckoutBelongs(ctx, workspace, checkoutPath)
	if !ok {
		return workspaceCheckoutStatusResult{}, &rpcError{
			Code:    errorCodeInvalidParams,
			Message: "checkout_path is not part of this workspace",
		}
	}

	if fileLimit <= 0 {
		fileLimit = gitstatus.DefaultFileLimit
	}
	if fileLimit > gitstatus.MaxFileLimit {
		fileLimit = gitstatus.MaxFileLimit
	}

	snap, _ := gitstatus.Snapshot(ctx, checkoutPath, gitstatus.SnapshotOpts{
		Mode:       gitstatus.ModeWithFiles,
		FileCursor: fileCursor,
		FileLimit:  fileLimit,
	})

	detail := gitCheckoutDetailDTO{
		gitCheckoutSummaryDTO: snapshotToSummaryDTO(snap, checkoutPath, role, gitstatus.WorktreeEntry{}),
		Files:                 filesToDTO(snap.Files),
		FilesTotal:            snap.FilesTotal,
		NextFileCursor:        snap.NextFileCursor,
	}

	return workspaceCheckoutStatusResult{
		Checkout:    detail,
		CollectedAt: now().UTC(),
	}, nil
}

// validateCheckoutBelongs decides whether checkoutPath is a legitimate part
// of workspace: it is either the workspace's main path, or one of the
// worktrees git reports for that repo.
func validateCheckoutBelongs(ctx context.Context, workspace workspaceRecord, checkoutPath string) (gitCheckoutRoleDTO, bool) {
	mainCanonical, _ := canonicalExistingPath(workspace.Path)
	checkoutCanonical, _ := canonicalExistingPath(checkoutPath)
	if mainCanonical != "" && checkoutCanonical != "" && mainCanonical == checkoutCanonical {
		return gitCheckoutRoleMain, true
	}
	repoRoot, err := gitstatus.FindRepoRoot(ctx, workspace.Path)
	if err != nil {
		return "", false
	}
	entries, err := gitstatus.ListWorktrees(ctx, repoRoot)
	if err != nil {
		return "", false
	}
	homeDir, _ := os.UserHomeDir()
	repoHash := repoHashForRoot(repoRoot)
	for _, e := range entries {
		entryCanonical, _ := canonicalExistingPath(e.Path)
		if entryCanonical == "" {
			continue
		}
		if entryCanonical == checkoutCanonical || e.Path == checkoutPath {
			return classifyRole(e.Path, homeDir, repoHash), true
		}
	}
	return "", false
}

// classifyRole labels a non-main checkout as either muxagent_managed (sitting
// under ~/.muxagent/worktrees/<repoHash>/) or external (anywhere else).
func classifyRole(checkoutPath, homeDir, repoHash string) gitCheckoutRoleDTO {
	if homeDir == "" || repoHash == "" {
		return gitCheckoutRoleExternal
	}
	managedPrefix := filepath.Join(homeDir, ".muxagent", "worktrees", repoHash) + string(os.PathSeparator)
	if strings.HasPrefix(checkoutPath, managedPrefix) {
		return gitCheckoutRoleMuxagentManaged
	}
	canonical, _ := canonicalExistingPath(checkoutPath)
	if canonical != "" && strings.HasPrefix(canonical, managedPrefix) {
		return gitCheckoutRoleMuxagentManaged
	}
	return gitCheckoutRoleExternal
}

// repoHashForRoot mirrors worktree.Create's hash: sha256(repoRoot) first 8
// hex chars. We keep a local copy rather than importing worktree to avoid an
// import cycle and to keep gitstatus standalone-testable.
func repoHashForRoot(repoRoot string) string {
	if repoRoot == "" {
		return ""
	}
	h := sha256.Sum256([]byte(repoRoot))
	return fmt.Sprintf("%x", h[:4])
}

func snapshotToSummaryDTO(snap gitstatus.CheckoutStatus, path string, role gitCheckoutRoleDTO, entry gitstatus.WorktreeEntry) gitCheckoutSummaryDTO {
	out := gitCheckoutSummaryDTO{
		Role:              role,
		Path:              path,
		Reachable:         snap.Reachable,
		UnreachableReason: snap.UnreachableReason,
		Locked:            entry.Locked,
		Prunable:          entry.Prunable,
		Branch:            snap.Branch,
		DetachedHead:      snap.DetachedHead,
		Upstream:          snap.Upstream,
		AheadCount:        snap.AheadCount,
		BehindCount:       snap.BehindCount,
		HeadCommit:        snap.HeadCommit,
		HeadSubject:       snap.HeadSubject,
		HeadAuthoredAt:    snap.HeadAuthoredAt,
		StagedCount:       snap.StagedCount,
		UnstagedCount:     snap.UnstagedCount,
		UntrackedCount:    snap.UntrackedCount,
		ConflictedCount:   snap.ConflictedCount,
		TotalChangeCount:  snap.StagedCount + snap.UnstagedCount + snap.UntrackedCount + snap.ConflictedCount,
	}
	if !snap.Reachable && entry.Path != "" && !pathExists(entry.Path) {
		out.UnreachableReason = gitstatus.ReasonPathMissing
	}
	return out
}

func filesToDTO(files []gitstatus.FileChange) []gitFileChangeDTO {
	out := make([]gitFileChangeDTO, 0, len(files))
	for _, fc := range files {
		out = append(out, gitFileChangeDTO{
			Path:     fc.Path,
			OrigPath: fc.OrigPath,
			XY:       fc.XY,
			Bucket:   string(fc.Bucket),
		})
	}
	return out
}

// canonicalExistingPath mirrors the worktree package helper but without
// importing that package (avoids a widening dependency graph for this file).
func canonicalExistingPath(path string) (string, error) {
	if path == "" {
		return "", nil
	}
	abs, err := filepath.Abs(path)
	if err != nil {
		return "", err
	}
	resolved, err := filepath.EvalSymlinks(abs)
	if err != nil {
		return "", err
	}
	return filepath.Clean(resolved), nil
}

func pathExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
