package claudesession

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestResolveLocalSessionUsesTranscriptMetadataAndUserTitle(t *testing.T) {
	root := t.TempDir()
	t.Setenv("CLAUDE_CONFIG_DIR", root)

	transcriptPath, err := TranscriptPath("/tmp/project", "session-claude")
	if err != nil {
		t.Fatalf("TranscriptPath: %v", err)
	}
	if err := os.MkdirAll(filepath.Dir(transcriptPath), 0o755); err != nil {
		t.Fatalf("mkdir transcript dir: %v", err)
	}
	content := "" +
		"{\"type\":\"file-history-snapshot\",\"timestamp\":\"2026-04-17T11:30:00Z\"}\n" +
		"{\"type\":\"user\",\"isMeta\":true,\"timestamp\":\"2026-04-17T11:31:00Z\",\"sessionId\":\"session-claude\",\"cwd\":\"/tmp/project\",\"message\":{\"role\":\"user\",\"content\":\"<local-command-caveat>ignore</local-command-caveat>\"}}\n" +
		"{\"type\":\"user\",\"timestamp\":\"2026-04-17T11:32:00Z\",\"sessionId\":\"session-claude\",\"cwd\":\"/tmp/project\",\"message\":{\"role\":\"user\",\"content\":\"Review the attach flow for Claude Code\"}}\n"
	if err := os.WriteFile(transcriptPath, []byte(content), 0o644); err != nil {
		t.Fatalf("write transcript: %v", err)
	}

	meta, err := ResolveLocalSession("session-claude")
	if err != nil {
		t.Fatalf("ResolveLocalSession: %v", err)
	}
	if meta.SessionID != "session-claude" {
		t.Fatalf("sessionID = %q, want session-claude", meta.SessionID)
	}
	if meta.CWD != "/tmp/project" {
		t.Fatalf("cwd = %q, want /tmp/project", meta.CWD)
	}
	if meta.Title != "Review the attach flow for Claude Code" {
		t.Fatalf("title = %q, want transcript user prompt", meta.Title)
	}
	if meta.Source != LocalTranscriptSource {
		t.Fatalf("source = %q, want %q", meta.Source, LocalTranscriptSource)
	}
	if got := meta.CreatedAt.UTC(); !got.Equal(time.Date(2026, 4, 17, 11, 30, 0, 0, time.UTC)) {
		t.Fatalf("createdAt = %v, want first transcript timestamp", got)
	}
	if got := meta.UpdatedAt.UTC(); !got.Equal(time.Date(2026, 4, 17, 11, 32, 0, 0, time.UTC)) {
		t.Fatalf("updatedAt = %v, want last transcript timestamp", got)
	}
}

func TestResolveLocalSessionFallsBackToSessionIDWhenOnlyCommandMetadataExists(t *testing.T) {
	root := t.TempDir()
	t.Setenv("CLAUDE_CONFIG_DIR", root)

	transcriptPath, err := TranscriptPath("/tmp/project", "session-command")
	if err != nil {
		t.Fatalf("TranscriptPath: %v", err)
	}
	if err := os.MkdirAll(filepath.Dir(transcriptPath), 0o755); err != nil {
		t.Fatalf("mkdir transcript dir: %v", err)
	}
	content := "" +
		"{\"type\":\"user\",\"timestamp\":\"2026-04-17T11:31:00Z\",\"sessionId\":\"session-command\",\"cwd\":\"/tmp/project\",\"message\":{\"role\":\"user\",\"content\":\"<command-name>/clear</command-name><command-message>clear</command-message>\"}}\n"
	if err := os.WriteFile(transcriptPath, []byte(content), 0o644); err != nil {
		t.Fatalf("write transcript: %v", err)
	}

	meta, err := ResolveLocalSession("session-command")
	if err != nil {
		t.Fatalf("ResolveLocalSession: %v", err)
	}
	if meta.Title != "session-command" {
		t.Fatalf("title = %q, want fallback session id basename", meta.Title)
	}
}

func TestResolveLocalSessionRejectsAmbiguousSessionID(t *testing.T) {
	root := t.TempDir()
	t.Setenv("CLAUDE_CONFIG_DIR", root)

	firstPath, err := TranscriptPath("/tmp/project-one", "shared-session")
	if err != nil {
		t.Fatalf("TranscriptPath first: %v", err)
	}
	secondPath, err := TranscriptPath("/tmp/project-two", "shared-session")
	if err != nil {
		t.Fatalf("TranscriptPath second: %v", err)
	}
	for _, path := range []string{firstPath, secondPath} {
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatalf("mkdir transcript dir: %v", err)
		}
		if err := os.WriteFile(path, []byte("{\"type\":\"user\",\"timestamp\":\"2026-04-17T11:31:00Z\",\"sessionId\":\"shared-session\",\"cwd\":\"/tmp/project\"}\n"), 0o644); err != nil {
			t.Fatalf("write transcript: %v", err)
		}
	}

	_, err = ResolveLocalSession("shared-session")
	if !errors.Is(err, ErrAmbiguousSessionID) {
		t.Fatalf("error = %v, want ErrAmbiguousSessionID", err)
	}
}

func TestResolveLocalSessionReturnsNotFound(t *testing.T) {
	root := t.TempDir()
	t.Setenv("CLAUDE_CONFIG_DIR", root)

	_, err := ResolveLocalSession("session-missing")
	if !errors.Is(err, ErrSessionNotFound) {
		t.Fatalf("error = %v, want ErrSessionNotFound", err)
	}
}
