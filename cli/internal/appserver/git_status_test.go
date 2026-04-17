package appserver

import (
	"context"
	"crypto/sha256"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"github.com/LaLanMo/muxagent/cli/internal/gitstatus"
)

// gitCmd and repo helpers are local so these tests can construct temp repos
// without importing the gitstatus test harness.
func gitCmd(t *testing.T, dir string, args ...string) {
	t.Helper()
	cmd := exec.Command("git", args...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(),
		"GIT_AUTHOR_NAME=tester",
		"GIT_AUTHOR_EMAIL=tester@example.com",
		"GIT_COMMITTER_NAME=tester",
		"GIT_COMMITTER_EMAIL=tester@example.com",
	)
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, string(out))
	}
}

func initGitRepo(t *testing.T, dir string) {
	t.Helper()
	gitCmd(t, dir, "init", "-q", "-b", "main")
	gitCmd(t, dir, "config", "user.name", "tester")
	gitCmd(t, dir, "config", "user.email", "tester@example.com")
	gitCmd(t, dir, "config", "commit.gpgsign", "false")
}

func commitFileInRepo(t *testing.T, root, rel, contents string) {
	t.Helper()
	full := filepath.Join(root, rel)
	if err := os.MkdirAll(filepath.Dir(full), 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	if err := os.WriteFile(full, []byte(contents), 0o644); err != nil {
		t.Fatalf("write: %v", err)
	}
	gitCmd(t, root, "add", rel)
	gitCmd(t, root, "commit", "-q", "-m", "add "+rel)
}

func TestWorkspaceGitStatusNotAGitRepo(t *testing.T) {
	server := newTestServer(t)
	defer func() { _ = server.Shutdown(context.Background(), false) }()

	workspacePath := t.TempDir() // no git init
	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	server.markInitialized()

	resultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodWorkspaceGitStatus,
		Params: mustRawParams(t, workspaceGitStatusParams{WorkspaceID: workspace.WorkspaceID}),
	})
	if rpcErr != nil {
		t.Fatalf("rpc error: %+v", rpcErr)
	}
	result := resultAny.(workspaceGitStatusResult)
	if result.Main.Reachable {
		t.Fatalf("expected main not reachable, got %+v", result.Main)
	}
	if result.Main.UnreachableReason == "" {
		t.Fatalf("expected unreachable reason, got empty")
	}
	if len(result.Worktrees) != 0 {
		t.Errorf("worktrees len=%d want 0", len(result.Worktrees))
	}
}

func TestWorkspaceGitStatusCleanRepo(t *testing.T) {
	server := newTestServer(t)
	defer func() { _ = server.Shutdown(context.Background(), false) }()

	workspacePath := t.TempDir()
	initGitRepo(t, workspacePath)
	commitFileInRepo(t, workspacePath, "README.md", "hi\n")
	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	server.markInitialized()

	resultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodWorkspaceGitStatus,
		Params: mustRawParams(t, workspaceGitStatusParams{WorkspaceID: workspace.WorkspaceID}),
	})
	if rpcErr != nil {
		t.Fatalf("rpc error: %+v", rpcErr)
	}
	result := resultAny.(workspaceGitStatusResult)
	if !result.Main.Reachable {
		t.Fatalf("expected main reachable, got %+v", result.Main)
	}
	if result.Main.Role != gitCheckoutRoleMain {
		t.Errorf("role=%q want main", result.Main.Role)
	}
	if result.Main.Branch != "main" {
		t.Errorf("branch=%q want main", result.Main.Branch)
	}
	if result.Main.TotalChangeCount != 0 {
		t.Errorf("TotalChangeCount=%d want 0", result.Main.TotalChangeCount)
	}
	if len(result.Worktrees) != 0 {
		t.Errorf("worktrees len=%d want 0 (main filtered)", len(result.Worktrees))
	}
}

func TestWorkspaceGitStatusMixedChanges(t *testing.T) {
	server := newTestServer(t)
	defer func() { _ = server.Shutdown(context.Background(), false) }()

	workspacePath := t.TempDir()
	initGitRepo(t, workspacePath)
	commitFileInRepo(t, workspacePath, "tracked.txt", "v1\n")
	// Staged modification.
	if err := os.WriteFile(filepath.Join(workspacePath, "tracked.txt"), []byte("v2\n"), 0o644); err != nil {
		t.Fatalf("write: %v", err)
	}
	gitCmd(t, workspacePath, "add", "tracked.txt")
	// Unstaged modification on top.
	if err := os.WriteFile(filepath.Join(workspacePath, "tracked.txt"), []byte("v3\n"), 0o644); err != nil {
		t.Fatalf("write: %v", err)
	}
	// Untracked file.
	if err := os.WriteFile(filepath.Join(workspacePath, "new.txt"), []byte("x"), 0o644); err != nil {
		t.Fatalf("write: %v", err)
	}

	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	server.markInitialized()

	resultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodWorkspaceGitStatus,
		Params: mustRawParams(t, workspaceGitStatusParams{WorkspaceID: workspace.WorkspaceID}),
	})
	if rpcErr != nil {
		t.Fatalf("rpc error: %+v", rpcErr)
	}
	result := resultAny.(workspaceGitStatusResult)
	if !result.Main.Reachable {
		t.Fatalf("not reachable: %+v", result.Main)
	}
	if result.Main.StagedCount != 1 || result.Main.UnstagedCount != 1 || result.Main.UntrackedCount != 1 {
		t.Fatalf("counts wrong: %+v", result.Main)
	}
	if result.Main.TotalChangeCount != 3 {
		t.Errorf("TotalChangeCount=%d want 3", result.Main.TotalChangeCount)
	}
}

func TestWorkspaceGitStatusWorktreeRoles(t *testing.T) {
	server := newTestServer(t)
	defer func() { _ = server.Shutdown(context.Background(), false) }()

	workspacePath := t.TempDir()
	initGitRepo(t, workspacePath)
	commitFileInRepo(t, workspacePath, "README.md", "hi\n")

	// Compute the hash the same way the implementation does: from the repo
	// root that git reports, not from an EvalSymlinks result.
	repoRoot, err := gitstatus.FindRepoRoot(context.Background(), workspacePath)
	if err != nil {
		t.Fatalf("find repo root: %v", err)
	}
	sum := sha256.Sum256([]byte(repoRoot))
	repoHash := fmt.Sprintf("%x", sum[:4])

	// Simulate a muxagent-managed worktree by putting the checkout under
	// $HOME/.muxagent/worktrees/<repoHash>/<task-id> for a fake HOME. Use
	// EvalSymlinks so the prefix match uses the same canonical form that git
	// reports for the worktree path.
	rawHome := t.TempDir()
	fakeHome, err := filepath.EvalSymlinks(rawHome)
	if err != nil {
		t.Fatalf("eval fake home: %v", err)
	}
	t.Setenv("HOME", fakeHome)
	managedParent := filepath.Join(fakeHome, ".muxagent", "worktrees", repoHash)
	if err := os.MkdirAll(managedParent, 0o755); err != nil {
		t.Fatalf("mkdir managed parent: %v", err)
	}
	managedPath := filepath.Join(managedParent, "task-abc")
	gitCmd(t, workspacePath, "worktree", "add", "-b", "managed", managedPath)

	// External worktree sits anywhere else.
	externalPath := filepath.Join(t.TempDir(), "external-wt")
	gitCmd(t, workspacePath, "worktree", "add", "-b", "external", externalPath)

	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	server.markInitialized()

	resultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodWorkspaceGitStatus,
		Params: mustRawParams(t, workspaceGitStatusParams{WorkspaceID: workspace.WorkspaceID}),
	})
	if rpcErr != nil {
		t.Fatalf("rpc error: %+v", rpcErr)
	}
	result := resultAny.(workspaceGitStatusResult)
	if !result.Main.Reachable || result.Main.Role != gitCheckoutRoleMain {
		t.Fatalf("main wrong: %+v", result.Main)
	}
	if len(result.Worktrees) != 2 {
		t.Fatalf("worktrees len=%d want 2: %+v", len(result.Worktrees), result.Worktrees)
	}
	var sawManaged, sawExternal bool
	for _, wt := range result.Worktrees {
		switch wt.Role {
		case gitCheckoutRoleMuxagentManaged:
			sawManaged = true
		case gitCheckoutRoleExternal:
			sawExternal = true
		}
	}
	if !sawManaged || !sawExternal {
		t.Errorf("roles missing: managed=%v external=%v (got %+v)", sawManaged, sawExternal, result.Worktrees)
	}
	if result.WorktreesTotalCount != 2 || result.WorktreesTruncated {
		t.Errorf("total=%d truncated=%v want 2 false", result.WorktreesTotalCount, result.WorktreesTruncated)
	}
}

func TestWorkspaceGitStatusPathMissing(t *testing.T) {
	server := newTestServer(t)
	defer func() { _ = server.Shutdown(context.Background(), false) }()

	// Register workspace against a dir that will be removed.
	workspacePath := filepath.Join(t.TempDir(), "gone")
	if err := os.MkdirAll(workspacePath, 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	if err := os.RemoveAll(workspacePath); err != nil {
		t.Fatalf("rm: %v", err)
	}
	server.markInitialized()

	resultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodWorkspaceGitStatus,
		Params: mustRawParams(t, workspaceGitStatusParams{WorkspaceID: workspace.WorkspaceID}),
	})
	if rpcErr != nil {
		t.Fatalf("rpc error: %+v", rpcErr)
	}
	result := resultAny.(workspaceGitStatusResult)
	if result.Main.Reachable {
		t.Fatalf("expected unreachable, got %+v", result.Main)
	}
	if result.Main.UnreachableReason == "" {
		t.Errorf("expected unreachable reason, got empty")
	}
}

func TestCheckoutStatusRejectsForeignPath(t *testing.T) {
	server := newTestServer(t)
	defer func() { _ = server.Shutdown(context.Background(), false) }()

	workspacePath := t.TempDir()
	initGitRepo(t, workspacePath)
	commitFileInRepo(t, workspacePath, "README.md", "hi\n")
	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}

	// A completely unrelated repo — belongs to neither workspace nor its worktrees.
	outsider := t.TempDir()
	initGitRepo(t, outsider)
	commitFileInRepo(t, outsider, "x.txt", "y\n")

	server.markInitialized()
	_, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodWorkspaceCheckoutStatus,
		Params: mustRawParams(t, workspaceCheckoutStatusParams{
			WorkspaceID:  workspace.WorkspaceID,
			CheckoutPath: outsider,
		}),
	})
	if rpcErr == nil || rpcErr.Code != errorCodeInvalidParams {
		t.Fatalf("expected invalid params, got %+v", rpcErr)
	}
}

func TestCheckoutStatusMainReturnsFiles(t *testing.T) {
	server := newTestServer(t)
	defer func() { _ = server.Shutdown(context.Background(), false) }()

	workspacePath := t.TempDir()
	initGitRepo(t, workspacePath)
	commitFileInRepo(t, workspacePath, "README.md", "hi\n")
	// Two untracked files.
	for _, name := range []string{"a.txt", "b.txt"} {
		if err := os.WriteFile(filepath.Join(workspacePath, name), []byte("x"), 0o644); err != nil {
			t.Fatalf("write: %v", err)
		}
	}
	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	server.markInitialized()

	resultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodWorkspaceCheckoutStatus,
		Params: mustRawParams(t, workspaceCheckoutStatusParams{
			WorkspaceID:  workspace.WorkspaceID,
			CheckoutPath: workspacePath,
			FileLimit:    10,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("rpc error: %+v", rpcErr)
	}
	result := resultAny.(workspaceCheckoutStatusResult)
	if !result.Checkout.Reachable {
		t.Fatalf("checkout not reachable: %+v", result.Checkout)
	}
	if result.Checkout.Role != gitCheckoutRoleMain {
		t.Errorf("role=%q want main", result.Checkout.Role)
	}
	if result.Checkout.FilesTotal != 2 {
		t.Errorf("FilesTotal=%d want 2", result.Checkout.FilesTotal)
	}
	if len(result.Checkout.Files) != 2 {
		t.Errorf("Files len=%d want 2", len(result.Checkout.Files))
	}
	if result.Checkout.NextFileCursor != "" {
		t.Errorf("NextFileCursor=%q want empty", result.Checkout.NextFileCursor)
	}
}

func TestCheckoutStatusPaginationRoundTrip(t *testing.T) {
	server := newTestServer(t)
	defer func() { _ = server.Shutdown(context.Background(), false) }()

	workspacePath := t.TempDir()
	initGitRepo(t, workspacePath)
	commitFileInRepo(t, workspacePath, "README.md", "hi\n")
	for i := 0; i < 7; i++ {
		p := filepath.Join(workspacePath, fmt.Sprintf("u%02d.txt", i))
		if err := os.WriteFile(p, []byte("x"), 0o644); err != nil {
			t.Fatalf("write: %v", err)
		}
	}
	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	server.markInitialized()

	seen := map[string]struct{}{}
	cursor := ""
	for page := 0; page < 10; page++ {
		resultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
			Method: methodWorkspaceCheckoutStatus,
			Params: mustRawParams(t, workspaceCheckoutStatusParams{
				WorkspaceID:  workspace.WorkspaceID,
				CheckoutPath: workspacePath,
				FileCursor:   cursor,
				FileLimit:    3,
			}),
		})
		if rpcErr != nil {
			t.Fatalf("rpc error: %+v", rpcErr)
		}
		result := resultAny.(workspaceCheckoutStatusResult)
		for _, fc := range result.Checkout.Files {
			if _, dup := seen[fc.Path]; dup {
				t.Fatalf("duplicate path across pages: %q", fc.Path)
			}
			seen[fc.Path] = struct{}{}
		}
		if result.Checkout.NextFileCursor == "" {
			break
		}
		cursor = result.Checkout.NextFileCursor
	}
	if len(seen) != 7 {
		t.Errorf("collected %d, want 7: %v", len(seen), seen)
	}
}
