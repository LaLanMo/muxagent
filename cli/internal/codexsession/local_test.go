package codexsession

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestResolveLocalSessionUsesTranscriptAndIndex(t *testing.T) {
	root := t.TempDir()
	t.Setenv("CODEX_HOME", root)

	transcriptPath := filepath.Join(
		root,
		"sessions",
		"2026",
		"04",
		"17",
		"rollout-2026-04-17T11-30-00-019d-session.jsonl",
	)
	if err := os.MkdirAll(filepath.Dir(transcriptPath), 0o755); err != nil {
		t.Fatalf("mkdir transcript dir: %v", err)
	}
	if err := os.WriteFile(
		transcriptPath,
		[]byte("{\"timestamp\":\"2026-04-17T11:30:00Z\",\"type\":\"session_meta\",\"payload\":{\"id\":\"019d-session\",\"cwd\":\"/tmp/project\"}}\n"),
		0o644,
	); err != nil {
		t.Fatalf("write transcript: %v", err)
	}
	if err := os.WriteFile(
		filepath.Join(root, "session_index.jsonl"),
		[]byte("{\"id\":\"019d-session\",\"thread_name\":\"Review plan\",\"updated_at\":\"2026-04-17T11:32:00Z\"}\n"),
		0o644,
	); err != nil {
		t.Fatalf("write index: %v", err)
	}

	meta, err := ResolveLocalSession("019d-session")
	if err != nil {
		t.Fatalf("ResolveLocalSession: %v", err)
	}
	if meta.CWD != "/tmp/project" {
		t.Fatalf("cwd = %q, want /tmp/project", meta.CWD)
	}
	if meta.Title != "Review plan" {
		t.Fatalf("title = %q, want Review plan", meta.Title)
	}
	if meta.Source != LocalTranscriptSource {
		t.Fatalf("source = %q, want %q", meta.Source, LocalTranscriptSource)
	}
	if got := meta.CreatedAt.UTC(); !got.Equal(time.Date(2026, 4, 17, 11, 30, 0, 0, time.UTC)) {
		t.Fatalf("createdAt = %v, want transcript timestamp", got)
	}
	if got := meta.UpdatedAt.UTC(); !got.Equal(time.Date(2026, 4, 17, 11, 32, 0, 0, time.UTC)) {
		t.Fatalf("updatedAt = %v, want index timestamp", got)
	}
}

func TestResolveLocalSessionUsesArchivedTranscript(t *testing.T) {
	root := t.TempDir()
	t.Setenv("CODEX_HOME", root)

	transcriptPath := filepath.Join(root, "archived_sessions", "session-019d-archived.jsonl")
	if err := os.MkdirAll(filepath.Dir(transcriptPath), 0o755); err != nil {
		t.Fatalf("mkdir archived dir: %v", err)
	}
	if err := os.WriteFile(
		transcriptPath,
		[]byte("{\"timestamp\":\"2026-04-17T11:30:00Z\",\"type\":\"session_meta\",\"payload\":{\"id\":\"019d-archived\",\"cwd\":\"/tmp/archived\"}}\n"),
		0o644,
	); err != nil {
		t.Fatalf("write transcript: %v", err)
	}

	meta, err := ResolveLocalSession("019d-archived")
	if err != nil {
		t.Fatalf("ResolveLocalSession: %v", err)
	}
	if meta.CWD != "/tmp/archived" {
		t.Fatalf("cwd = %q, want /tmp/archived", meta.CWD)
	}
	if meta.Title != "session-019d-archived" {
		t.Fatalf("title = %q, want fallback transcript basename", meta.Title)
	}
}

func TestResolveLocalSessionReturnsMetadataWithoutCWD(t *testing.T) {
	root := t.TempDir()
	t.Setenv("CODEX_HOME", root)

	transcriptPath := filepath.Join(
		root,
		"sessions",
		"2026",
		"04",
		"17",
		"rollout-2026-04-17T11-30-00-019d-no-cwd.jsonl",
	)
	if err := os.MkdirAll(filepath.Dir(transcriptPath), 0o755); err != nil {
		t.Fatalf("mkdir transcript dir: %v", err)
	}
	if err := os.WriteFile(
		transcriptPath,
		[]byte("{\"timestamp\":\"2026-04-17T11:30:00Z\",\"type\":\"session_meta\",\"payload\":{\"id\":\"019d-no-cwd\"}}\n"),
		0o644,
	); err != nil {
		t.Fatalf("write transcript: %v", err)
	}

	meta, err := ResolveLocalSession("019d-no-cwd")
	if err != nil {
		t.Fatalf("ResolveLocalSession: %v", err)
	}
	if meta.CWD != "" {
		t.Fatalf("cwd = %q, want empty", meta.CWD)
	}
}

func TestResolveLocalSession_RejectsAmbiguousSessionID(t *testing.T) {
	root := t.TempDir()
	t.Setenv("CODEX_HOME", root)

	firstPath := filepath.Join(
		root,
		"sessions",
		"2026",
		"04",
		"17",
		"rollout-2026-04-17T11-30-00-shared-id.jsonl",
	)
	if err := os.MkdirAll(filepath.Dir(firstPath), 0o755); err != nil {
		t.Fatalf("mkdir first transcript dir: %v", err)
	}
	if err := os.WriteFile(
		firstPath,
		[]byte("{\"timestamp\":\"2026-04-17T11:30:00Z\",\"type\":\"session_meta\",\"payload\":{\"id\":\"shared-id\",\"cwd\":\"/tmp/first\"}}\n"),
		0o644,
	); err != nil {
		t.Fatalf("write first transcript: %v", err)
	}

	secondPath := filepath.Join(
		root,
		"sessions",
		"2026",
		"04",
		"18",
		"rollout-2026-04-18T12-00-00-shared-id.jsonl",
	)
	if err := os.MkdirAll(filepath.Dir(secondPath), 0o755); err != nil {
		t.Fatalf("mkdir second transcript dir: %v", err)
	}
	if err := os.WriteFile(
		secondPath,
		[]byte("{\"timestamp\":\"2026-04-18T12:00:00Z\",\"type\":\"session_meta\",\"payload\":{\"id\":\"shared-id\",\"cwd\":\"/tmp/second\"}}\n"),
		0o644,
	); err != nil {
		t.Fatalf("write second transcript: %v", err)
	}

	_, err := ResolveLocalSession("shared-id")
	if !errors.Is(err, ErrAmbiguousSessionID) {
		t.Fatalf("error = %v, want ErrAmbiguousSessionID", err)
	}
}

func TestResolveLocalSessionReturnsNotFound(t *testing.T) {
	root := t.TempDir()
	t.Setenv("CODEX_HOME", root)

	_, err := ResolveLocalSession("019d-missing")
	if !errors.Is(err, ErrSessionNotFound) {
		t.Fatalf("error = %v, want ErrSessionNotFound", err)
	}
}
