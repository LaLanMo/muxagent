package opencodesession

import (
	"database/sql"
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"

	_ "modernc.org/sqlite"
)

func TestResolveLocalSessionUsesOpencodeSessionTable(t *testing.T) {
	root := t.TempDir()
	t.Setenv("XDG_DATA_HOME", root)

	dbPath := filepath.Join(root, "opencode", "opencode.db")
	if err := os.MkdirAll(filepath.Dir(dbPath), 0o755); err != nil {
		t.Fatalf("mkdir db dir: %v", err)
	}
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	defer db.Close()

	if _, err := db.Exec(`
		CREATE TABLE session (
			id TEXT PRIMARY KEY,
			project_id TEXT NOT NULL,
			parent_id TEXT,
			slug TEXT NOT NULL,
			directory TEXT NOT NULL,
			title TEXT NOT NULL,
			version TEXT NOT NULL,
			share_url TEXT,
			summary_additions INTEGER,
			summary_deletions INTEGER,
			summary_files INTEGER,
			summary_diffs TEXT,
			revert TEXT,
			permission TEXT,
			time_created INTEGER NOT NULL,
			time_updated INTEGER NOT NULL,
			time_compacting INTEGER,
			time_archived INTEGER,
			workspace_id TEXT
		)
	`); err != nil {
		t.Fatalf("create session table: %v", err)
	}
	if _, err := db.Exec(
		`INSERT INTO session (id, project_id, slug, directory, title, version, time_created, time_updated) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
		"ses-test-1",
		"proj-1",
		"calm-wizard",
		"/tmp/opencode-project",
		"Opencode attach test",
		"1.4.3",
		int64(1775826902718),
		int64(1775826934257),
	); err != nil {
		t.Fatalf("insert session: %v", err)
	}

	meta, err := ResolveLocalSession("ses-test-1")
	if err != nil {
		t.Fatalf("ResolveLocalSession: %v", err)
	}
	if meta.CWD != "/tmp/opencode-project" {
		t.Fatalf("cwd = %q, want /tmp/opencode-project", meta.CWD)
	}
	if meta.Title != "Opencode attach test" {
		t.Fatalf("title = %q, want Opencode attach test", meta.Title)
	}
	if meta.Source != LocalStoreSource {
		t.Fatalf("source = %q, want %q", meta.Source, LocalStoreSource)
	}
	if got := meta.CreatedAt.UTC(); !got.Equal(time.UnixMilli(1775826902718).UTC()) {
		t.Fatalf("createdAt = %v, want unix millis", got)
	}
	if got := meta.UpdatedAt.UTC(); !got.Equal(time.UnixMilli(1775826934257).UTC()) {
		t.Fatalf("updatedAt = %v, want unix millis", got)
	}
}

func TestResolveLocalSessionFallsBackToSessionIDWhenTitleMissing(t *testing.T) {
	root := t.TempDir()
	t.Setenv("XDG_DATA_HOME", root)

	dbPath := filepath.Join(root, "opencode", "opencode.db")
	if err := os.MkdirAll(filepath.Dir(dbPath), 0o755); err != nil {
		t.Fatalf("mkdir db dir: %v", err)
	}
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	defer db.Close()

	if _, err := db.Exec(`CREATE TABLE session (id TEXT PRIMARY KEY, project_id TEXT NOT NULL, slug TEXT NOT NULL, directory TEXT NOT NULL, title TEXT NOT NULL, version TEXT NOT NULL, time_created INTEGER NOT NULL, time_updated INTEGER NOT NULL)`); err != nil {
		t.Fatalf("create session table: %v", err)
	}
	if _, err := db.Exec(
		`INSERT INTO session (id, project_id, slug, directory, title, version, time_created, time_updated) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
		"ses-test-2",
		"proj-2",
		"quiet-harbor",
		"/tmp/opencode-project",
		"",
		"1.4.3",
		int64(1775826902718),
		int64(1775826902718),
	); err != nil {
		t.Fatalf("insert session: %v", err)
	}

	meta, err := ResolveLocalSession("ses-test-2")
	if err != nil {
		t.Fatalf("ResolveLocalSession: %v", err)
	}
	if meta.Title != "ses-test-2" {
		t.Fatalf("title = %q, want session id fallback", meta.Title)
	}
}

func TestResolveLocalSessionReturnsNotFound(t *testing.T) {
	root := t.TempDir()
	t.Setenv("XDG_DATA_HOME", root)

	dbPath := filepath.Join(root, "opencode", "opencode.db")
	if err := os.MkdirAll(filepath.Dir(dbPath), 0o755); err != nil {
		t.Fatalf("mkdir db dir: %v", err)
	}
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	defer db.Close()
	if _, err := db.Exec(`CREATE TABLE session (id TEXT PRIMARY KEY, project_id TEXT NOT NULL, slug TEXT NOT NULL, directory TEXT NOT NULL, title TEXT NOT NULL, version TEXT NOT NULL, time_created INTEGER NOT NULL, time_updated INTEGER NOT NULL)`); err != nil {
		t.Fatalf("create session table: %v", err)
	}

	_, err = ResolveLocalSession("ses-missing")
	if !errors.Is(err, ErrSessionNotFound) {
		t.Fatalf("error = %v, want ErrSessionNotFound", err)
	}
}
