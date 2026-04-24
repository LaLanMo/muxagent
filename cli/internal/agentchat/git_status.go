package agentchat

import (
	"context"
	"time"

	"github.com/LaLanMo/muxagent/cli/internal/appwire"
	"github.com/LaLanMo/muxagent/cli/internal/gitstatus"
)

// SessionGitStatus returns a git status snapshot for the session's cwd.
// The session cwd is not necessarily a git repo, so unreachable checkouts are
// represented in the result rather than as RPC errors.
func (s *Service) SessionGitStatus(ctx context.Context, params appwire.SessionGitStatusParams) (any, string) {
	if params.SessionID == "" {
		return nil, "missing sessionId"
	}
	cwd, ok := s.SessionCWD(params.SessionID)
	if !ok || cwd == "" {
		return nil, "unknown session"
	}

	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	snap, _ := gitstatus.Snapshot(ctx, cwd, gitstatus.SnapshotOpts{
		Mode:       gitstatus.ModeWithFiles,
		FileCursor: params.FileCursor,
		FileLimit:  clampFileLimit(params.FileLimit),
	})
	return toSessionGitStatusResult(snap), ""
}

func clampFileLimit(n int) int {
	if n <= 0 {
		return gitstatus.DefaultFileLimit
	}
	if n > gitstatus.MaxFileLimit {
		return gitstatus.MaxFileLimit
	}
	return n
}

func toSessionGitStatusResult(snap gitstatus.CheckoutStatus) appwire.SessionGitStatusResult {
	files := make([]appwire.SessionGitFile, 0, len(snap.Files))
	for _, fc := range snap.Files {
		files = append(files, appwire.SessionGitFile{
			Path:     fc.Path,
			OrigPath: fc.OrigPath,
			XY:       fc.XY,
			Bucket:   string(fc.Bucket),
		})
	}
	return appwire.SessionGitStatusResult{
		Reachable:         snap.Reachable,
		UnreachableReason: snap.UnreachableReason,
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
		Files:             files,
		FilesTotal:        snap.FilesTotal,
		NextFileCursor:    snap.NextFileCursor,
		CollectedAt:       time.Now().UTC(),
	}
}
