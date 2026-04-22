package gitdiff

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestCommitDiffReturnsPurePatchAndMetadata(t *testing.T) {
	repo := t.TempDir()
	runGitForTest(t, repo, "init")
	runGitForTest(t, repo, "config", "user.name", "Fixture Author")
	runGitForTest(t, repo, "config", "user.email", "fixture@example.com")

	writeFileForTest(t, filepath.Join(repo, "src", "auth.ts"), "export function signIn() {\n  return session;\n}\n")
	writeFileForTest(t, filepath.Join(repo, "src", "session.ts"), "export const TTL = 3600;\n")
	runGitForTest(t, repo, "add", ".")
	runGitForTest(t, repo, "commit", "-m", "Initial fixture")

	writeFileForTest(t, filepath.Join(repo, "src", "auth.ts"), "export function signIn() {\n  return session;\n}\n\nexport function signOut() {\n  session.clear();\n}\n")
	writeFileForTest(t, filepath.Join(repo, "src", "session.ts"), "export const TTL = 7200;\n")
	runGitForTest(t, repo, "add", ".")
	runGitForTest(t, repo, "commit", "-m", "Fixture commit diff")
	hash := strings.TrimSpace(runGitForTest(t, repo, "rev-parse", "HEAD"))

	patch, err := CommitDiff(context.Background(), repo, hash, CommitDiffOpts{})
	if err != nil {
		t.Fatalf("CommitDiff returned error: %v", err)
	}
	if !patch.Reachable {
		t.Fatalf("expected reachable patch, got reason %q", patch.UnreachableReason)
	}
	if !strings.HasPrefix(patch.Patch, "diff --git ") {
		t.Fatalf("expected pure unified patch, got prefix %q", patch.Patch[:min(len(patch.Patch), 80)])
	}
	for _, unwanted := range []string{
		"commit " + hash,
		"Author:",
		"Date:",
		"files changed",
		"src/auth.ts     |",
	} {
		if strings.Contains(patch.Patch, unwanted) {
			t.Fatalf("patch contains stat/header prelude %q:\n%s", unwanted, patch.Patch)
		}
	}
	for _, wanted := range []string{
		"diff --git a/src/auth.ts b/src/auth.ts",
		"diff --git a/src/session.ts b/src/session.ts",
		"+export function signOut()",
		"+export const TTL = 7200;",
	} {
		if !strings.Contains(patch.Patch, wanted) {
			t.Fatalf("patch missing %q:\n%s", wanted, patch.Patch)
		}
	}
	if patch.FileCount != 2 {
		t.Fatalf("expected file count 2, got %d", patch.FileCount)
	}
	if patch.Subject != "Fixture commit diff" {
		t.Fatalf("expected subject from metadata, got %q", patch.Subject)
	}
	if patch.Author != "Fixture Author" || patch.AuthorMail != "fixture@example.com" {
		t.Fatalf("unexpected author metadata: %q <%s>", patch.Author, patch.AuthorMail)
	}
	if patch.Hash != hash {
		t.Fatalf("expected hash %q, got %q", hash, patch.Hash)
	}
	if patch.AuthoredAt == nil {
		t.Fatal("expected authored timestamp")
	}
}

func runGitForTest(t *testing.T, repo string, args ...string) string {
	t.Helper()
	cmd := exec.Command("git", append([]string{"-C", repo}, args...)...)
	cmd.Env = append(os.Environ(),
		"GIT_AUTHOR_DATE=2026-01-01T12:00:00Z",
		"GIT_COMMITTER_DATE=2026-01-01T12:00:00Z",
	)
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("git %s failed: %v\n%s", strings.Join(args, " "), err, out)
	}
	return string(out)
}

func writeFileForTest(t *testing.T, path string, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}
