package gitstatus

import (
	"strings"
	"testing"
)

// mkRec joins fields with " " and appends NUL as record terminator.
func mkRec(parts ...string) string {
	return strings.Join(parts, " ") + "\x00"
}

func TestParsePorcelainHeaders(t *testing.T) {
	var b strings.Builder
	b.WriteString(mkRec("#", "branch.oid", "abc123"))
	b.WriteString(mkRec("#", "branch.head", "main"))
	b.WriteString(mkRec("#", "branch.upstream", "origin/main"))
	b.WriteString(mkRec("#", "branch.ab", "+2", "-3"))

	ps, err := parsePorcelainV2([]byte(b.String()))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if ps.Head != "abc123" {
		t.Errorf("Head=%q", ps.Head)
	}
	if ps.Branch != "main" {
		t.Errorf("Branch=%q", ps.Branch)
	}
	if ps.Upstream != "origin/main" {
		t.Errorf("Upstream=%q", ps.Upstream)
	}
	if ps.Ahead != 2 || ps.Behind != 3 {
		t.Errorf("ab=%d/%d", ps.Ahead, ps.Behind)
	}
}

func TestParsePorcelainDetachedHead(t *testing.T) {
	var b strings.Builder
	b.WriteString(mkRec("#", "branch.oid", "abc123"))
	b.WriteString(mkRec("#", "branch.head", "(detached)"))

	ps, err := parsePorcelainV2([]byte(b.String()))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if !ps.Detached {
		t.Errorf("expected Detached=true")
	}
	if ps.Branch != "" {
		t.Errorf("Branch=%q want empty", ps.Branch)
	}
}

func TestParsePorcelainType1StagedAndUnstaged(t *testing.T) {
	// "1 MM N... 100644 100644 100644 <h1> <h2> path/to/file"
	rec := mkRec("1", "MM", "N...", "100644", "100644", "100644", "abc", "def", "path/to/file")
	ps, err := parsePorcelainV2([]byte(rec))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if len(ps.Staged) != 1 || ps.Staged[0].Path != "path/to/file" {
		t.Errorf("Staged=%+v", ps.Staged)
	}
	if len(ps.Unstaged) != 1 || ps.Unstaged[0].Path != "path/to/file" {
		t.Errorf("Unstaged=%+v", ps.Unstaged)
	}
}

func TestParsePorcelainType1OnlyStaged(t *testing.T) {
	rec := mkRec("1", "M.", "N...", "100644", "100644", "100644", "abc", "def", "foo.txt")
	ps, err := parsePorcelainV2([]byte(rec))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if len(ps.Staged) != 1 || ps.Staged[0].Path != "foo.txt" {
		t.Errorf("Staged=%+v", ps.Staged)
	}
	if len(ps.Unstaged) != 0 {
		t.Errorf("Unstaged=%+v should be empty", ps.Unstaged)
	}
}

func TestParsePorcelainType1OnlyUnstaged(t *testing.T) {
	rec := mkRec("1", ".M", "N...", "100644", "100644", "100644", "abc", "def", "foo.txt")
	ps, err := parsePorcelainV2([]byte(rec))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if len(ps.Staged) != 0 {
		t.Errorf("Staged=%+v should be empty", ps.Staged)
	}
	if len(ps.Unstaged) != 1 || ps.Unstaged[0].Path != "foo.txt" {
		t.Errorf("Unstaged=%+v", ps.Unstaged)
	}
}

func TestParsePorcelainType2Rename(t *testing.T) {
	// "2 R. N... 100644 100644 100644 <h1> <h2> R100 new/path"
	// followed by a separate NUL-delimited record with orig path.
	body := "2 R. N... 100644 100644 100644 abc def R100 new/path\x00orig/path\x00"
	ps, err := parsePorcelainV2([]byte(body))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if len(ps.Staged) != 1 {
		t.Fatalf("Staged len=%d", len(ps.Staged))
	}
	if ps.Staged[0].Path != "new/path" {
		t.Errorf("Staged[0].Path=%q", ps.Staged[0].Path)
	}
	if ps.Staged[0].OrigPath != "orig/path" {
		t.Errorf("Staged[0].OrigPath=%q", ps.Staged[0].OrigPath)
	}
}

func TestParsePorcelainUnmerged(t *testing.T) {
	// "u UU N... <m1> <m2> <m3> <mW> <h1> <h2> <h3> conflict.txt"
	rec := mkRec("u", "UU", "N...", "100644", "100644", "100644", "100644", "a", "b", "c", "conflict.txt")
	ps, err := parsePorcelainV2([]byte(rec))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if len(ps.Conflicted) != 1 || ps.Conflicted[0].Path != "conflict.txt" {
		t.Errorf("Conflicted=%+v", ps.Conflicted)
	}
}

func TestParsePorcelainUntracked(t *testing.T) {
	rec := mkRec("?", "new-file.go")
	ps, err := parsePorcelainV2([]byte(rec))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if len(ps.Untracked) != 1 || ps.Untracked[0].Path != "new-file.go" {
		t.Errorf("Untracked=%+v", ps.Untracked)
	}
}

func TestParsePorcelainPathWithSpaces(t *testing.T) {
	rec := mkRec("1", "M.", "N...", "100644", "100644", "100644", "abc", "def", "dir/file with spaces.txt")
	ps, err := parsePorcelainV2([]byte(rec))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if len(ps.Staged) != 1 || ps.Staged[0].Path != "dir/file with spaces.txt" {
		t.Errorf("Staged=%+v", ps.Staged)
	}
}

func TestParseWorktreePorcelain(t *testing.T) {
	input := `worktree /repo/main
HEAD abc123
branch refs/heads/main

worktree /tmp/wt1
HEAD def456
detached

worktree /tmp/wt2
HEAD 0000
branch refs/heads/feature
locked held-by-user
`
	entries := parseWorktreePorcelain([]byte(input))
	if len(entries) != 3 {
		t.Fatalf("entries len=%d want 3", len(entries))
	}
	if entries[0].Path != "/repo/main" || entries[0].Branch != "main" || entries[0].Detached {
		t.Errorf("entries[0]=%+v", entries[0])
	}
	if entries[1].Path != "/tmp/wt1" || !entries[1].Detached {
		t.Errorf("entries[1]=%+v", entries[1])
	}
	if entries[2].Path != "/tmp/wt2" || entries[2].Branch != "feature" || !entries[2].Locked {
		t.Errorf("entries[2]=%+v", entries[2])
	}
}
