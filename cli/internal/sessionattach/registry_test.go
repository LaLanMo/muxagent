package sessionattach

import (
	"database/sql"
	"errors"
	"os"
	"path/filepath"
	"testing"

	"github.com/LaLanMo/muxagent/cli/internal/claudesession"
	"github.com/LaLanMo/muxagent/cli/internal/config"
	_ "modernc.org/sqlite"
)

func TestRegistryResolveUnsupportedRuntime(t *testing.T) {
	registry := NewRegistry()

	_, err := registry.Resolve("gemini-cli", "session-1")
	if !errors.Is(err, ErrUnsupportedRuntime) {
		t.Fatalf("error = %v, want ErrUnsupportedRuntime", err)
	}
}

func TestRegistryResolveCodexMapsNotFoundToGenericSentinel(t *testing.T) {
	t.Setenv("CODEX_HOME", t.TempDir())

	registry := NewRegistry()

	_, err := registry.Resolve("codex", "missing")
	if !errors.Is(err, ErrSessionNotFound) {
		t.Fatalf("error = %v, want ErrSessionNotFound", err)
	}
}

func TestRegistryResolveClaudeUsesLocalTranscriptMetadata(t *testing.T) {
	root := t.TempDir()
	t.Setenv("CLAUDE_CONFIG_DIR", root)

	transcriptPath, err := claudesession.TranscriptPath("/tmp/project", "session-claude")
	if err != nil {
		t.Fatalf("TranscriptPath: %v", err)
	}
	if err := os.MkdirAll(filepath.Dir(transcriptPath), 0o755); err != nil {
		t.Fatalf("mkdir transcript dir: %v", err)
	}
	if err := os.WriteFile(
		transcriptPath,
		[]byte("{\"type\":\"user\",\"timestamp\":\"2026-04-17T11:31:00Z\",\"sessionId\":\"session-claude\",\"cwd\":\"/tmp/project\",\"message\":{\"role\":\"user\",\"content\":\"Attach this Claude session\"}}\n"),
		0o644,
	); err != nil {
		t.Fatalf("write transcript: %v", err)
	}

	registry := NewRegistry()

	meta, err := registry.Resolve("claude-code", "session-claude")
	if err != nil {
		t.Fatalf("Resolve: %v", err)
	}
	if meta.CWD != "/tmp/project" {
		t.Fatalf("cwd = %q, want /tmp/project", meta.CWD)
	}
	if meta.Title != "Attach this Claude session" {
		t.Fatalf("title = %q, want transcript title", meta.Title)
	}
}

func TestRegistryResolveCopilotUsesLocalSessionStateMetadata(t *testing.T) {
	root := t.TempDir()
	t.Setenv("COPILOT_HOME", root)

	path := filepath.Join(root, "session-state", "session-copilot", "events.jsonl")
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("mkdir session-state dir: %v", err)
	}
	if err := os.WriteFile(path, []byte(
		"{\"type\":\"session.start\",\"timestamp\":\"2026-04-18T12:00:00Z\",\"data\":{\"sessionId\":\"session-copilot\",\"startTime\":\"2026-04-18T12:00:00Z\",\"context\":{\"cwd\":\"/tmp/project\"}}}\n"+
			"{\"type\":\"user.message\",\"timestamp\":\"2026-04-18T12:00:05Z\",\"data\":{\"content\":\"Attach this Copilot session\"}}\n",
	), 0o644); err != nil {
		t.Fatalf("write session state: %v", err)
	}

	registry := NewRegistry()

	meta, err := registry.Resolve(string(config.RuntimeCopilot), "session-copilot")
	if err != nil {
		t.Fatalf("Resolve: %v", err)
	}
	if meta.CWD != "/tmp/project" {
		t.Fatalf("cwd = %q, want /tmp/project", meta.CWD)
	}
	if meta.Title != "Attach this Copilot session" {
		t.Fatalf("title = %q, want prompt title", meta.Title)
	}
	if meta.CreatedAt.IsZero() || meta.UpdatedAt.IsZero() {
		t.Fatalf("times = created %v updated %v, want non-zero", meta.CreatedAt, meta.UpdatedAt)
	}
}

func TestRegistryResolveOpenCodeUsesLocalStoreMetadata(t *testing.T) {
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
		"ses-open-1",
		"proj-1",
		"quiet-brook",
		"/tmp/opencode-project",
		"Attach this OpenCode session",
		"1.4.3",
		int64(1775826902718),
		int64(1775826934257),
	); err != nil {
		t.Fatalf("insert session: %v", err)
	}

	registry := NewRegistry()

	meta, err := registry.Resolve(string(config.RuntimeOpenCode), "ses-open-1")
	if err != nil {
		t.Fatalf("Resolve: %v", err)
	}
	if meta.CWD != "/tmp/opencode-project" {
		t.Fatalf("cwd = %q, want /tmp/opencode-project", meta.CWD)
	}
	if meta.Title != "Attach this OpenCode session" {
		t.Fatalf("title = %q, want store title", meta.Title)
	}
	if meta.CreatedAt.IsZero() || meta.UpdatedAt.IsZero() {
		t.Fatalf("times = created %v updated %v, want non-zero", meta.CreatedAt, meta.UpdatedAt)
	}
}
