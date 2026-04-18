package goosesession

import (
	"database/sql"
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"

	_ "modernc.org/sqlite"
)

func TestResolveLocalSessionUsesSessionTableMetadata(t *testing.T) {
	root := t.TempDir()
	t.Setenv("XDG_DATA_HOME", root)

	dbPath := filepath.Join(root, "goose", "sessions", "sessions.db")
	if err := os.MkdirAll(filepath.Dir(dbPath), 0o755); err != nil {
		t.Fatalf("mkdir db dir: %v", err)
	}
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	defer db.Close()

	if _, err := db.Exec(`CREATE TABLE sessions (id TEXT PRIMARY KEY, name TEXT NOT NULL DEFAULT '', description TEXT NOT NULL DEFAULT '', user_set_name BOOLEAN DEFAULT FALSE, session_type TEXT NOT NULL DEFAULT 'user', working_dir TEXT NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, extension_data TEXT DEFAULT '{}', total_tokens INTEGER, input_tokens INTEGER, output_tokens INTEGER, accumulated_total_tokens INTEGER, accumulated_input_tokens INTEGER, accumulated_output_tokens INTEGER, schedule_id TEXT, recipe_json TEXT, user_recipe_values_json TEXT, provider_name TEXT, model_config_json TEXT, goose_mode TEXT NOT NULL DEFAULT 'auto')`); err != nil {
		t.Fatalf("create sessions table: %v", err)
	}
	if _, err := db.Exec(`CREATE TABLE messages (id INTEGER PRIMARY KEY AUTOINCREMENT, message_id TEXT, session_id TEXT NOT NULL REFERENCES sessions(id), role TEXT NOT NULL, content_json TEXT NOT NULL, created_timestamp INTEGER NOT NULL, timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP, tokens INTEGER, metadata_json TEXT)`); err != nil {
		t.Fatalf("create messages table: %v", err)
	}
	if _, err := db.Exec(
		`INSERT INTO sessions (id, name, description, working_dir, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)`,
		"20260418_1",
		"Explain this project",
		"",
		"/tmp/goose-project",
		"2026-04-18 12:34:56",
		"2026-04-18 12:35:10",
	); err != nil {
		t.Fatalf("insert session: %v", err)
	}

	meta, err := ResolveLocalSession("20260418_1")
	if err != nil {
		t.Fatalf("ResolveLocalSession: %v", err)
	}
	if meta.CWD != "/tmp/goose-project" {
		t.Fatalf("cwd = %q, want /tmp/goose-project", meta.CWD)
	}
	if meta.Title != "Explain this project" {
		t.Fatalf("title = %q, want session name", meta.Title)
	}
	if meta.Source != LocalStoreSource {
		t.Fatalf("source = %q, want %q", meta.Source, LocalStoreSource)
	}
	if got := meta.CreatedAt.UTC(); !got.Equal(time.Date(2026, 4, 18, 12, 34, 56, 0, time.UTC)) {
		t.Fatalf("createdAt = %v, want created_at timestamp", got)
	}
	if got := meta.UpdatedAt.UTC(); !got.Equal(time.Date(2026, 4, 18, 12, 35, 10, 0, time.UTC)) {
		t.Fatalf("updatedAt = %v, want updated_at timestamp", got)
	}
}

func TestResolveLocalSessionFallsBackToFirstUserPromptForGenericNames(t *testing.T) {
	root := t.TempDir()
	t.Setenv("XDG_DATA_HOME", root)

	dbPath := filepath.Join(root, "goose", "sessions", "sessions.db")
	if err := os.MkdirAll(filepath.Dir(dbPath), 0o755); err != nil {
		t.Fatalf("mkdir db dir: %v", err)
	}
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	defer db.Close()

	if _, err := db.Exec(`CREATE TABLE sessions (id TEXT PRIMARY KEY, name TEXT NOT NULL DEFAULT '', description TEXT NOT NULL DEFAULT '', user_set_name BOOLEAN DEFAULT FALSE, session_type TEXT NOT NULL DEFAULT 'user', working_dir TEXT NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, extension_data TEXT DEFAULT '{}', total_tokens INTEGER, input_tokens INTEGER, output_tokens INTEGER, accumulated_total_tokens INTEGER, accumulated_input_tokens INTEGER, accumulated_output_tokens INTEGER, schedule_id TEXT, recipe_json TEXT, user_recipe_values_json TEXT, provider_name TEXT, model_config_json TEXT, goose_mode TEXT NOT NULL DEFAULT 'auto')`); err != nil {
		t.Fatalf("create sessions table: %v", err)
	}
	if _, err := db.Exec(`CREATE TABLE messages (id INTEGER PRIMARY KEY AUTOINCREMENT, message_id TEXT, session_id TEXT NOT NULL REFERENCES sessions(id), role TEXT NOT NULL, content_json TEXT NOT NULL, created_timestamp INTEGER NOT NULL, timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP, tokens INTEGER, metadata_json TEXT)`); err != nil {
		t.Fatalf("create messages table: %v", err)
	}
	if _, err := db.Exec(
		`INSERT INTO sessions (id, name, description, working_dir, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)`,
		"20260418_2",
		"ACP Session",
		"",
		"/tmp/goose-project",
		"2026-04-18 12:34:56",
		"2026-04-18 12:35:10",
	); err != nil {
		t.Fatalf("insert session: %v", err)
	}
	if _, err := db.Exec(
		`INSERT INTO messages (session_id, role, content_json, created_timestamp) VALUES (?, ?, ?, ?)`,
		"20260418_2",
		"user",
		`[{"type":"text","text":"Reply with exactly ok and nothing else."}]`,
		int64(1776515698),
	); err != nil {
		t.Fatalf("insert message: %v", err)
	}

	meta, err := ResolveLocalSession("20260418_2")
	if err != nil {
		t.Fatalf("ResolveLocalSession: %v", err)
	}
	if meta.Title != "Reply with exactly ok and nothing else." {
		t.Fatalf("title = %q, want first user prompt", meta.Title)
	}
}

func TestResolveLocalSessionReturnsNotFound(t *testing.T) {
	root := t.TempDir()
	t.Setenv("XDG_DATA_HOME", root)

	dbPath := filepath.Join(root, "goose", "sessions", "sessions.db")
	if err := os.MkdirAll(filepath.Dir(dbPath), 0o755); err != nil {
		t.Fatalf("mkdir db dir: %v", err)
	}
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	defer db.Close()
	if _, err := db.Exec(`CREATE TABLE sessions (id TEXT PRIMARY KEY, name TEXT NOT NULL DEFAULT '', description TEXT NOT NULL DEFAULT '', user_set_name BOOLEAN DEFAULT FALSE, session_type TEXT NOT NULL DEFAULT 'user', working_dir TEXT NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, extension_data TEXT DEFAULT '{}', total_tokens INTEGER, input_tokens INTEGER, output_tokens INTEGER, accumulated_total_tokens INTEGER, accumulated_input_tokens INTEGER, accumulated_output_tokens INTEGER, schedule_id TEXT, recipe_json TEXT, user_recipe_values_json TEXT, provider_name TEXT, model_config_json TEXT, goose_mode TEXT NOT NULL DEFAULT 'auto')`); err != nil {
		t.Fatalf("create sessions table: %v", err)
	}

	_, err = ResolveLocalSession("missing")
	if !errors.Is(err, ErrSessionNotFound) {
		t.Fatalf("error = %v, want ErrSessionNotFound", err)
	}
}
