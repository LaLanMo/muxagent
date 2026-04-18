package copilotsession

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestResolveLocalSessionUsesSessionStateEvents(t *testing.T) {
	root := t.TempDir()
	t.Setenv("COPILOT_HOME", root)

	path := filepath.Join(root, "session-state", "session-copilot", "events.jsonl")
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("mkdir session-state dir: %v", err)
	}
	if err := os.WriteFile(path, []byte(
		"{\"type\":\"session.start\",\"timestamp\":\"2026-04-18T12:00:00Z\",\"data\":{\"sessionId\":\"session-copilot\",\"startTime\":\"2026-04-18T11:59:59.500Z\",\"context\":{\"cwd\":\"/tmp/project\"}}}\n"+
			"{\"type\":\"user.message\",\"timestamp\":\"2026-04-18T12:00:05Z\",\"data\":{\"content\":\"Attach this Copilot session\"}}\n"+
			"{\"type\":\"session.resume\",\"timestamp\":\"2026-04-18T12:01:00Z\",\"data\":{\"resumeTime\":\"2026-04-18T12:01:00Z\",\"context\":{\"cwd\":\"/tmp/project-resumed\"}}}\n",
	), 0o644); err != nil {
		t.Fatalf("write session state: %v", err)
	}

	meta, err := ResolveLocalSession("session-copilot")
	if err != nil {
		t.Fatalf("ResolveLocalSession: %v", err)
	}
	if meta.CWD != "/tmp/project-resumed" {
		t.Fatalf("cwd = %q, want /tmp/project-resumed", meta.CWD)
	}
	if meta.Title != "Attach this Copilot session" {
		t.Fatalf("title = %q, want prompt-derived title", meta.Title)
	}
	if meta.Source != LocalSessionStateSource {
		t.Fatalf("source = %q, want %q", meta.Source, LocalSessionStateSource)
	}
	if got := meta.CreatedAt.UTC(); !got.Equal(time.Date(2026, 4, 18, 11, 59, 59, 500000000, time.UTC)) {
		t.Fatalf("createdAt = %v, want session start time", got)
	}
	if got := meta.UpdatedAt.UTC(); !got.Equal(time.Date(2026, 4, 18, 12, 1, 0, 0, time.UTC)) {
		t.Fatalf("updatedAt = %v, want latest event time", got)
	}
}

func TestResolveLocalSessionFallsBackToSessionIDWhenPromptMissing(t *testing.T) {
	root := t.TempDir()
	t.Setenv("COPILOT_HOME", root)

	path := filepath.Join(root, "session-state", "session-copilot", "events.jsonl")
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("mkdir session-state dir: %v", err)
	}
	if err := os.WriteFile(path, []byte(
		"{\"type\":\"session.start\",\"timestamp\":\"2026-04-18T12:00:00Z\",\"data\":{\"sessionId\":\"session-copilot\",\"startTime\":\"2026-04-18T12:00:00Z\",\"context\":{\"cwd\":\"/tmp/project\"}}}\n",
	), 0o644); err != nil {
		t.Fatalf("write session state: %v", err)
	}

	meta, err := ResolveLocalSession("session-copilot")
	if err != nil {
		t.Fatalf("ResolveLocalSession: %v", err)
	}
	if meta.Title != "session-copilot" {
		t.Fatalf("title = %q, want session id fallback", meta.Title)
	}
}

func TestResolveLocalSessionReturnsNotFound(t *testing.T) {
	root := t.TempDir()
	t.Setenv("COPILOT_HOME", root)

	_, err := ResolveLocalSession("missing")
	if err != ErrSessionNotFound {
		t.Fatalf("error = %v, want ErrSessionNotFound", err)
	}
}
