package geminisession

import (
	"os"
	"path/filepath"
	"testing"
)

func TestResolveLocalSessionUsesChatFileMetadata(t *testing.T) {
	root := t.TempDir()
	t.Setenv("GEMINI_HOME", root)

	sessionPath := filepath.Join(root, "tmp", "muxagent", "chats", "session-2026-04-18T20-00-abcd1234.json")
	if err := os.MkdirAll(filepath.Dir(sessionPath), 0o755); err != nil {
		t.Fatalf("mkdir chats dir: %v", err)
	}
	if err := os.WriteFile(
		filepath.Join(root, "tmp", "muxagent", ".project_root"),
		[]byte("/tmp/gemini-project\n"),
		0o644,
	); err != nil {
		t.Fatalf("write project root: %v", err)
	}
	if err := os.WriteFile(sessionPath, []byte(`{
  "sessionId": "abcd1234-aed7-45d2-a46c-08a4c638e8e2",
  "startTime": "2026-04-18T12:00:00Z",
  "lastUpdated": "2026-04-18T12:00:05Z",
  "messages": [
    {
      "type": "user",
      "content": [{"text": "Attach this Gemini session"}]
    },
    {
      "type": "gemini",
      "content": "OK"
    }
  ]
}`), 0o644); err != nil {
		t.Fatalf("write session file: %v", err)
	}

	meta, err := ResolveLocalSession("abcd1234-aed7-45d2-a46c-08a4c638e8e2")
	if err != nil {
		t.Fatalf("ResolveLocalSession: %v", err)
	}
	if meta.CWD != "/tmp/gemini-project" {
		t.Fatalf("cwd = %q, want /tmp/gemini-project", meta.CWD)
	}
	if meta.Title != "Attach this Gemini session" {
		t.Fatalf("title = %q, want prompt title", meta.Title)
	}
	if meta.SessionPath != sessionPath {
		t.Fatalf("session path = %q, want %q", meta.SessionPath, sessionPath)
	}
	if meta.CreatedAt.IsZero() || meta.UpdatedAt.IsZero() {
		t.Fatalf("times = created %v updated %v, want non-zero", meta.CreatedAt, meta.UpdatedAt)
	}
}

func TestResolveLocalSessionPrefersCandidateWithProjectRoot(t *testing.T) {
	root := t.TempDir()
	t.Setenv("GEMINI_HOME", root)

	paths := []string{
		filepath.Join(root, "tmp", "orphan", "chats", "session-1.json"),
		filepath.Join(root, "tmp", "muxagent", "chats", "session-2.json"),
	}
	for _, path := range paths {
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatalf("mkdir chats dir: %v", err)
		}
	}
	if err := os.WriteFile(
		filepath.Join(root, "tmp", "muxagent", ".project_root"),
		[]byte("/tmp/better-project\n"),
		0o644,
	); err != nil {
		t.Fatalf("write project root: %v", err)
	}

	const sessionJSON = `{
  "sessionId": "9c781817-aed7-45d2-a46c-08a4c638e8e2",
  "startTime": "2026-04-16T14:04:52.293Z",
  "lastUpdated": "2026-04-16T14:04:55.858Z",
  "messages": [
    {
      "type": "user",
      "content": [{"text": "hi"}]
    }
  ]
}`
	for _, path := range paths {
		if err := os.WriteFile(path, []byte(sessionJSON), 0o644); err != nil {
			t.Fatalf("write session file: %v", err)
		}
	}

	meta, err := ResolveLocalSession("9c781817-aed7-45d2-a46c-08a4c638e8e2")
	if err != nil {
		t.Fatalf("ResolveLocalSession: %v", err)
	}
	if meta.CWD != "/tmp/better-project" {
		t.Fatalf("cwd = %q, want /tmp/better-project", meta.CWD)
	}
	if meta.SessionPath != paths[1] {
		t.Fatalf("session path = %q, want %q", meta.SessionPath, paths[1])
	}
}

func TestResolveLocalSessionSkipsBootstrapPrompt(t *testing.T) {
	root := t.TempDir()
	t.Setenv("GEMINI_HOME", root)

	sessionPath := filepath.Join(root, "tmp", "muxagent", "chats", "session-bootstrap.json")
	if err := os.MkdirAll(filepath.Dir(sessionPath), 0o755); err != nil {
		t.Fatalf("mkdir chats dir: %v", err)
	}
	if err := os.WriteFile(sessionPath, []byte(`{
  "sessionId": "bootstrap-session",
  "messages": [
    {
      "type": "user",
      "content": [{"text": "You are an AI agent that brings the power of Gemini directly into the terminal. Follow instructions."}]
    },
    {
      "type": "user",
      "content": [{"text": "continue"}]
    }
  ]
}`), 0o644); err != nil {
		t.Fatalf("write session file: %v", err)
	}

	meta, err := ResolveLocalSession("bootstrap-session")
	if err != nil {
		t.Fatalf("ResolveLocalSession: %v", err)
	}
	if meta.Title != "continue" {
		t.Fatalf("title = %q, want continue", meta.Title)
	}
}
