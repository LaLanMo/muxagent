package gitstatus

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

// gitCmd runs a git command in dir, failing the test on error.
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

func initRepo(t *testing.T) string {
	t.Helper()
	root := t.TempDir()
	gitCmd(t, root, "init", "-q", "-b", "main")
	gitCmd(t, root, "config", "user.name", "tester")
	gitCmd(t, root, "config", "user.email", "tester@example.com")
	gitCmd(t, root, "config", "commit.gpgsign", "false")
	return root
}

func commitFile(t *testing.T, root, rel, contents string) {
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

func TestSnapshotNotAGitRepo(t *testing.T) {
	root := t.TempDir() // empty dir, no git init
	s, err := Snapshot(context.Background(), root, SnapshotOpts{Mode: ModeSummaryOnly})
	if err != nil {
		t.Fatalf("err: %v", err)
	}
	if s.Reachable {
		t.Fatalf("expected Reachable=false, got %+v", s)
	}
	if s.UnreachableReason != ReasonNotAGitRepo {
		t.Errorf("reason=%q want %q", s.UnreachableReason, ReasonNotAGitRepo)
	}
}

func TestSnapshotCleanRepo(t *testing.T) {
	root := initRepo(t)
	commitFile(t, root, "README.md", "hello\n")

	s, err := Snapshot(context.Background(), root, SnapshotOpts{Mode: ModeSummaryOnly})
	if err != nil {
		t.Fatalf("err: %v", err)
	}
	if !s.Reachable {
		t.Fatalf("not reachable: %+v", s)
	}
	if s.StagedCount != 0 || s.UnstagedCount != 0 || s.UntrackedCount != 0 || s.ConflictedCount != 0 {
		t.Errorf("expected clean, got %+v", s)
	}
	if s.Branch != "main" {
		t.Errorf("Branch=%q want main", s.Branch)
	}
	if s.HeadCommit == "" {
		t.Errorf("HeadCommit is empty")
	}
	if s.HeadSubject == "" {
		t.Errorf("HeadSubject is empty")
	}
}

func TestSnapshotMixedChanges(t *testing.T) {
	root := initRepo(t)
	commitFile(t, root, "tracked.txt", "v1\n")
	// Staged modification of tracked file.
	if err := os.WriteFile(filepath.Join(root, "tracked.txt"), []byte("v2\n"), 0o644); err != nil {
		t.Fatalf("write: %v", err)
	}
	gitCmd(t, root, "add", "tracked.txt")
	// Unstaged modification on top.
	if err := os.WriteFile(filepath.Join(root, "tracked.txt"), []byte("v3\n"), 0o644); err != nil {
		t.Fatalf("write: %v", err)
	}
	// Untracked file.
	if err := os.WriteFile(filepath.Join(root, "brand-new.go"), []byte("package x\n"), 0o644); err != nil {
		t.Fatalf("write: %v", err)
	}

	s, err := Snapshot(context.Background(), root, SnapshotOpts{Mode: ModeWithFiles})
	if err != nil {
		t.Fatalf("err: %v", err)
	}
	if !s.Reachable {
		t.Fatalf("not reachable: %+v", s)
	}
	if s.StagedCount != 1 {
		t.Errorf("StagedCount=%d want 1", s.StagedCount)
	}
	if s.UnstagedCount != 1 {
		t.Errorf("UnstagedCount=%d want 1", s.UnstagedCount)
	}
	if s.UntrackedCount != 1 {
		t.Errorf("UntrackedCount=%d want 1", s.UntrackedCount)
	}
	if s.FilesTotal != 3 {
		t.Errorf("FilesTotal=%d want 3", s.FilesTotal)
	}
	if len(s.Files) != 3 {
		t.Errorf("Files len=%d want 3", len(s.Files))
	}
}

func TestSnapshotPaginationRoundTrip(t *testing.T) {
	root := initRepo(t)
	commitFile(t, root, "README.md", "root\n")
	// Create 10 untracked files with stable names.
	for i := 0; i < 10; i++ {
		p := filepath.Join(root, fmt.Sprintf("u%02d.txt", i))
		if err := os.WriteFile(p, []byte("x"), 0o644); err != nil {
			t.Fatalf("write: %v", err)
		}
	}

	collected := map[string]struct{}{}
	cursor := ""
	var totalFromFirstPage int
	for page := 0; page < 20; page++ {
		s, err := Snapshot(context.Background(), root, SnapshotOpts{
			Mode:       ModeWithFiles,
			FileLimit:  3,
			FileCursor: cursor,
		})
		if err != nil {
			t.Fatalf("err: %v", err)
		}
		if page == 0 {
			totalFromFirstPage = s.FilesTotal
		}
		for _, fc := range s.Files {
			if _, dup := collected[fc.Path]; dup {
				t.Fatalf("duplicate path across pages: %q", fc.Path)
			}
			collected[fc.Path] = struct{}{}
		}
		if s.NextFileCursor == "" {
			break
		}
		cursor = s.NextFileCursor
	}
	if len(collected) != 10 {
		t.Errorf("collected %d files, want 10; collected=%v", len(collected), collected)
	}
	if totalFromFirstPage != 10 {
		t.Errorf("FilesTotal first page=%d want 10", totalFromFirstPage)
	}
}

func TestSnapshotPathMissing(t *testing.T) {
	s, err := Snapshot(context.Background(), "/tmp/definitely-does-not-exist-"+t.Name(), SnapshotOpts{Mode: ModeSummaryOnly})
	if err != nil {
		t.Fatalf("err: %v", err)
	}
	if s.Reachable {
		t.Fatalf("expected Reachable=false, got %+v", s)
	}
	// Could map to path_missing or internal depending on git version message.
	if s.UnreachableReason == "" {
		t.Errorf("unreachable reason is empty")
	}
}

func TestSnapshotIgnoresInheritedGITDIR(t *testing.T) {
	root := initRepo(t)
	commitFile(t, root, "README.md", "hello\n")

	// Point GIT_DIR at a nonexistent place. sanitizedEnv must strip it before
	// we exec git, otherwise the status call will fail spuriously.
	t.Setenv("GIT_DIR", "/tmp/does-not-exist-"+t.Name())
	t.Setenv("GIT_WORK_TREE", "/tmp/does-not-exist-"+t.Name())

	s, err := Snapshot(context.Background(), root, SnapshotOpts{Mode: ModeSummaryOnly})
	if err != nil {
		t.Fatalf("err: %v", err)
	}
	if !s.Reachable {
		t.Fatalf("not reachable despite sanitized env: %+v", s)
	}
	if s.Branch != "main" {
		t.Errorf("Branch=%q want main", s.Branch)
	}
}

func TestListWorktrees(t *testing.T) {
	root := initRepo(t)
	commitFile(t, root, "README.md", "hello\n")
	wtRoot := filepath.Join(t.TempDir(), "wt1")
	gitCmd(t, root, "worktree", "add", "-b", "feature", wtRoot)

	entries, err := ListWorktrees(context.Background(), root)
	if err != nil {
		t.Fatalf("err: %v", err)
	}
	if len(entries) != 2 {
		t.Fatalf("entries len=%d want 2: %+v", len(entries), entries)
	}
	var sawMain, sawFeature bool
	for _, e := range entries {
		switch e.Branch {
		case "main":
			sawMain = true
		case "feature":
			sawFeature = true
		}
	}
	if !sawMain || !sawFeature {
		t.Errorf("missing branches: main=%v feature=%v", sawMain, sawFeature)
	}
}

func TestFindRepoRoot(t *testing.T) {
	root := initRepo(t)
	commitFile(t, root, "README.md", "hello\n")
	sub := filepath.Join(root, "sub", "dir")
	if err := os.MkdirAll(sub, 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	got, err := FindRepoRoot(context.Background(), sub)
	if err != nil {
		t.Fatalf("err: %v", err)
	}
	resolvedRoot, _ := filepath.EvalSymlinks(root)
	resolvedGot, _ := filepath.EvalSymlinks(got)
	if resolvedGot != resolvedRoot {
		t.Errorf("FindRepoRoot=%q want %q", resolvedGot, resolvedRoot)
	}
}
