package relayws

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"github.com/LaLanMo/muxagent/cli/internal/appwire"
	"github.com/stretchr/testify/require"
)

func gitExec(t *testing.T, dir string, args ...string) {
	t.Helper()
	cmd := exec.Command("git", args...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(),
		"GIT_AUTHOR_NAME=tester",
		"GIT_AUTHOR_EMAIL=tester@example.com",
		"GIT_COMMITTER_NAME=tester",
		"GIT_COMMITTER_EMAIL=tester@example.com",
	)
	out, err := cmd.CombinedOutput()
	require.NoErrorf(t, err, "git %v: %s", args, string(out))
}

func initTestRepo(t *testing.T, dir string) {
	t.Helper()
	gitExec(t, dir, "init", "-q", "-b", "main")
	gitExec(t, dir, "config", "user.name", "tester")
	gitExec(t, dir, "config", "user.email", "tester@example.com")
	gitExec(t, dir, "config", "commit.gpgsign", "false")
}

func seedCommit(t *testing.T, dir, rel, contents string) {
	t.Helper()
	full := filepath.Join(dir, rel)
	require.NoError(t, os.MkdirAll(filepath.Dir(full), 0o755))
	require.NoError(t, os.WriteFile(full, []byte(contents), 0o644))
	gitExec(t, dir, "add", rel)
	gitExec(t, dir, "commit", "-q", "-m", "add "+rel)
}

func TestRpcSessionGitStatusMissingSession(t *testing.T) {
	c := &Client{sessionCWD: map[string]string{}}
	_, errStr := c.rpcSessionGitStatus(context.Background(), appwire.SessionGitStatusParams{})
	require.Equal(t, "missing sessionId", errStr)
}

func TestRpcSessionGitStatusUnknownSession(t *testing.T) {
	c := &Client{sessionCWD: map[string]string{}}
	_, errStr := c.rpcSessionGitStatus(context.Background(), appwire.SessionGitStatusParams{SessionID: "nope"})
	require.Equal(t, "unknown session", errStr)
}

func TestRpcSessionGitStatusCwdNotARepo(t *testing.T) {
	root := t.TempDir()
	c := &Client{sessionCWD: map[string]string{"sid": root}}
	resultAny, errStr := c.rpcSessionGitStatus(context.Background(), appwire.SessionGitStatusParams{SessionID: "sid"})
	require.Empty(t, errStr)
	result := resultAny.(appwire.SessionGitStatusResult)
	require.False(t, result.Reachable)
	require.NotEmpty(t, result.UnreachableReason)
}

func TestRpcSessionGitStatusMixedChanges(t *testing.T) {
	root := t.TempDir()
	initTestRepo(t, root)
	seedCommit(t, root, "tracked.txt", "v1\n")
	// Staged modification.
	require.NoError(t, os.WriteFile(filepath.Join(root, "tracked.txt"), []byte("v2\n"), 0o644))
	gitExec(t, root, "add", "tracked.txt")
	// Unstaged modification on top.
	require.NoError(t, os.WriteFile(filepath.Join(root, "tracked.txt"), []byte("v3\n"), 0o644))
	// Untracked file.
	require.NoError(t, os.WriteFile(filepath.Join(root, "new.txt"), []byte("x"), 0o644))

	c := &Client{sessionCWD: map[string]string{"sid": root}}
	resultAny, errStr := c.rpcSessionGitStatus(context.Background(), appwire.SessionGitStatusParams{SessionID: "sid"})
	require.Empty(t, errStr)
	result := resultAny.(appwire.SessionGitStatusResult)
	require.True(t, result.Reachable)
	require.Equal(t, "main", result.Branch)
	require.Equal(t, 1, result.StagedCount)
	require.Equal(t, 1, result.UnstagedCount)
	require.Equal(t, 1, result.UntrackedCount)
	require.Equal(t, 3, result.TotalChangeCount)
	require.Equal(t, 3, result.FilesTotal)
	require.Len(t, result.Files, 3)
}

func TestRpcSessionGitStatusPaginationRoundTrip(t *testing.T) {
	root := t.TempDir()
	initTestRepo(t, root)
	seedCommit(t, root, "README.md", "hi\n")
	for i := 0; i < 7; i++ {
		p := filepath.Join(root, fmt.Sprintf("u%02d.txt", i))
		require.NoError(t, os.WriteFile(p, []byte("x"), 0o644))
	}

	c := &Client{sessionCWD: map[string]string{"sid": root}}
	seen := map[string]struct{}{}
	cursor := ""
	for page := 0; page < 10; page++ {
		resultAny, errStr := c.rpcSessionGitStatus(context.Background(), appwire.SessionGitStatusParams{
			SessionID:  "sid",
			FileCursor: cursor,
			FileLimit:  3,
		})
		require.Empty(t, errStr)
		result := resultAny.(appwire.SessionGitStatusResult)
		for _, fc := range result.Files {
			_, dup := seen[fc.Path]
			require.Falsef(t, dup, "duplicate path across pages: %s", fc.Path)
			seen[fc.Path] = struct{}{}
		}
		if result.NextFileCursor == "" {
			break
		}
		cursor = result.NextFileCursor
	}
	require.Len(t, seen, 7)
}
