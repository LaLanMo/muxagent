package sessionattach

import (
	"errors"
	"os"
	"path/filepath"
	"testing"

	"github.com/LaLanMo/muxagent/cli/internal/claudesession"
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
