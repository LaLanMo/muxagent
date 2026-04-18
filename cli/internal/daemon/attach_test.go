package daemon

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"github.com/LaLanMo/muxagent/cli/internal/appwire"
	"github.com/LaLanMo/muxagent/cli/internal/claudesession"
	"github.com/LaLanMo/muxagent/cli/internal/control"
	"github.com/LaLanMo/muxagent/cli/internal/relayws"
	_ "modernc.org/sqlite"
)

type fakeAttachPublisher struct {
	machineID string
	events    []appwire.Event
	err       error
}

func (f *fakeAttachPublisher) SendLiveEvent(event appwire.Event) error {
	if f.err != nil {
		return f.err
	}
	f.events = append(f.events, event)
	return nil
}

func (f *fakeAttachPublisher) MachineID() string {
	return f.machineID
}

func TestAttachSessionUsesLocalRuntimeMetadataAndBroadcasts(t *testing.T) {
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
		[]byte("{\"id\":\"019d-session\",\"thread_name\":\"Attached title\",\"updated_at\":\"2026-04-17T11:32:00Z\"}\n"),
		0o644,
	); err != nil {
		t.Fatalf("write index: %v", err)
	}

	publisher := &fakeAttachPublisher{machineID: "machine-1"}
	d := &Daemon{attachPublisher: publisher}

	resp, err := d.attachSession(context.Background(), control.AttachSessionRequest{
		SessionID: "019d-session",
		Runtime:   "codex",
	})
	if err != nil {
		t.Fatalf("attachSession: %v", err)
	}
	if !resp.Broadcasted {
		t.Fatalf("Broadcasted = false, want true")
	}
	if resp.Runtime != "codex" {
		t.Fatalf("runtime = %q, want codex", resp.Runtime)
	}
	if resp.CWD != "/tmp/project" {
		t.Fatalf("cwd = %q, want /tmp/project", resp.CWD)
	}
	if resp.Title != "Attached title" {
		t.Fatalf("title = %q, want Attached title", resp.Title)
	}
	if len(publisher.events) != 1 {
		t.Fatalf("events = %d, want 1", len(publisher.events))
	}
	event := publisher.events[0]
	if event.Type != appwire.EventSessionStatus {
		t.Fatalf("event.Type = %q, want %q", event.Type, appwire.EventSessionStatus)
	}
	if event.SessionInfo == nil || event.SessionInfo.App.Runtime != "codex" {
		t.Fatalf("runtime = %+v, want codex", event.SessionInfo)
	}
	if event.SessionInfo == nil || event.SessionInfo.App.MachineID != "machine-1" {
		t.Fatalf("machineID = %+v, want machine-1", event.SessionInfo)
	}
}

func TestAttachSessionUsesClaudeLocalRuntimeMetadataAndBroadcasts(t *testing.T) {
	root := t.TempDir()
	t.Setenv("CLAUDE_CONFIG_DIR", root)

	transcriptPath, err := claudesession.TranscriptPath("/tmp/claude-project", "session-claude")
	if err != nil {
		t.Fatalf("TranscriptPath: %v", err)
	}
	if err := os.MkdirAll(filepath.Dir(transcriptPath), 0o755); err != nil {
		t.Fatalf("mkdir transcript dir: %v", err)
	}
	if err := os.WriteFile(
		transcriptPath,
		[]byte("{\"type\":\"user\",\"timestamp\":\"2026-04-17T11:30:00Z\",\"sessionId\":\"session-claude\",\"cwd\":\"/tmp/claude-project\",\"message\":{\"role\":\"user\",\"content\":\"Attach this Claude session\"}}\n"),
		0o644,
	); err != nil {
		t.Fatalf("write transcript: %v", err)
	}

	publisher := &fakeAttachPublisher{machineID: "machine-2"}
	d := &Daemon{attachPublisher: publisher}

	resp, err := d.attachSession(context.Background(), control.AttachSessionRequest{
		SessionID: "session-claude",
		Runtime:   "claude-code",
	})
	if err != nil {
		t.Fatalf("attachSession: %v", err)
	}
	if !resp.Broadcasted {
		t.Fatalf("Broadcasted = false, want true")
	}
	if resp.Runtime != "claude-code" {
		t.Fatalf("runtime = %q, want claude-code", resp.Runtime)
	}
	if resp.CWD != "/tmp/claude-project" {
		t.Fatalf("cwd = %q, want /tmp/claude-project", resp.CWD)
	}
	if resp.Title != "Attach this Claude session" {
		t.Fatalf("title = %q, want Attach this Claude session", resp.Title)
	}
	if len(publisher.events) != 1 {
		t.Fatalf("events = %d, want 1", len(publisher.events))
	}
	event := publisher.events[0]
	if event.SessionInfo == nil || event.SessionInfo.App.Runtime != "claude-code" {
		t.Fatalf("runtime = %+v, want claude-code", event.SessionInfo)
	}
	if event.SessionInfo == nil || event.SessionInfo.App.MachineID != "machine-2" {
		t.Fatalf("machineID = %+v, want machine-2", event.SessionInfo)
	}
}

func TestAttachSessionUsesCopilotLocalRuntimeMetadataAndBroadcasts(t *testing.T) {
	root := t.TempDir()
	t.Setenv("COPILOT_HOME", root)

	path := filepath.Join(root, "session-state", "session-copilot", "events.jsonl")
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("mkdir session-state dir: %v", err)
	}
	if err := os.WriteFile(path, []byte(
		"{\"type\":\"session.start\",\"timestamp\":\"2026-04-18T12:00:00Z\",\"data\":{\"sessionId\":\"session-copilot\",\"startTime\":\"2026-04-18T12:00:00Z\",\"context\":{\"cwd\":\"/tmp/copilot-project\"}}}\n"+
			"{\"type\":\"user.message\",\"timestamp\":\"2026-04-18T12:00:05Z\",\"data\":{\"content\":\"Attach this Copilot session\"}}\n",
	), 0o644); err != nil {
		t.Fatalf("write session state: %v", err)
	}

	publisher := &fakeAttachPublisher{machineID: "machine-25"}
	d := &Daemon{attachPublisher: publisher}

	resp, err := d.attachSession(context.Background(), control.AttachSessionRequest{
		SessionID: "session-copilot",
		Runtime:   "copilot",
	})
	if err != nil {
		t.Fatalf("attachSession: %v", err)
	}
	if !resp.Broadcasted {
		t.Fatalf("Broadcasted = false, want true")
	}
	if resp.Runtime != "copilot" {
		t.Fatalf("runtime = %q, want copilot", resp.Runtime)
	}
	if resp.CWD != "/tmp/copilot-project" {
		t.Fatalf("cwd = %q, want /tmp/copilot-project", resp.CWD)
	}
	if resp.Title != "Attach this Copilot session" {
		t.Fatalf("title = %q, want Attach this Copilot session", resp.Title)
	}
	if len(publisher.events) != 1 {
		t.Fatalf("events = %d, want 1", len(publisher.events))
	}
	event := publisher.events[0]
	if event.SessionInfo == nil || event.SessionInfo.App.Runtime != "copilot" {
		t.Fatalf("runtime = %+v, want copilot", event.SessionInfo)
	}
	if event.SessionInfo == nil || event.SessionInfo.App.MachineID != "machine-25" {
		t.Fatalf("machineID = %+v, want machine-25", event.SessionInfo)
	}
}

func TestAttachSessionUsesGeminiLocalRuntimeMetadataAndBroadcasts(t *testing.T) {
	root := t.TempDir()
	t.Setenv("GEMINI_HOME", root)

	path := filepath.Join(root, "tmp", "muxagent", "chats", "session-gemini.json")
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("mkdir chats dir: %v", err)
	}
	if err := os.WriteFile(filepath.Join(root, "tmp", "muxagent", ".project_root"), []byte("/tmp/gemini-project\n"), 0o644); err != nil {
		t.Fatalf("write project root: %v", err)
	}
	if err := os.WriteFile(path, []byte(`{
  "sessionId": "session-gemini",
  "startTime": "2026-04-18T12:00:00Z",
  "lastUpdated": "2026-04-18T12:00:05Z",
  "messages": [
    {
      "type": "user",
      "content": [{"text": "Attach this Gemini session"}]
    }
  ]
}`), 0o644); err != nil {
		t.Fatalf("write session file: %v", err)
	}

	publisher := &fakeAttachPublisher{machineID: "machine-27"}
	d := &Daemon{attachPublisher: publisher}

	resp, err := d.attachSession(context.Background(), control.AttachSessionRequest{
		SessionID: "session-gemini",
		Runtime:   "gemini",
	})
	if err != nil {
		t.Fatalf("attachSession: %v", err)
	}
	if !resp.Broadcasted {
		t.Fatalf("Broadcasted = false, want true")
	}
	if resp.Runtime != "gemini" {
		t.Fatalf("runtime = %q, want gemini", resp.Runtime)
	}
	if resp.CWD != "/tmp/gemini-project" {
		t.Fatalf("cwd = %q, want /tmp/gemini-project", resp.CWD)
	}
	if resp.Title != "Attach this Gemini session" {
		t.Fatalf("title = %q, want Attach this Gemini session", resp.Title)
	}
	if len(publisher.events) != 1 {
		t.Fatalf("events = %d, want 1", len(publisher.events))
	}
	event := publisher.events[0]
	if event.SessionInfo == nil || event.SessionInfo.App.Runtime != "gemini" {
		t.Fatalf("runtime = %+v, want gemini", event.SessionInfo)
	}
	if event.SessionInfo == nil || event.SessionInfo.App.MachineID != "machine-27" {
		t.Fatalf("machineID = %+v, want machine-27", event.SessionInfo)
	}
}

func TestAttachSessionUsesGooseLocalRuntimeMetadataAndBroadcasts(t *testing.T) {
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
		"20260418_4",
		"Attach this Goose session",
		"",
		"/tmp/goose-project",
		"2026-04-18 12:34:56",
		"2026-04-18 12:35:10",
	); err != nil {
		t.Fatalf("insert session: %v", err)
	}

	publisher := &fakeAttachPublisher{machineID: "machine-26"}
	d := &Daemon{attachPublisher: publisher}

	resp, err := d.attachSession(context.Background(), control.AttachSessionRequest{
		SessionID: "20260418_4",
		Runtime:   "goose",
	})
	if err != nil {
		t.Fatalf("attachSession: %v", err)
	}
	if !resp.Broadcasted {
		t.Fatalf("Broadcasted = false, want true")
	}
	if resp.Runtime != "goose" {
		t.Fatalf("runtime = %q, want goose", resp.Runtime)
	}
	if resp.CWD != "/tmp/goose-project" {
		t.Fatalf("cwd = %q, want /tmp/goose-project", resp.CWD)
	}
	if resp.Title != "Attach this Goose session" {
		t.Fatalf("title = %q, want Attach this Goose session", resp.Title)
	}
	if len(publisher.events) != 1 {
		t.Fatalf("events = %d, want 1", len(publisher.events))
	}
	event := publisher.events[0]
	if event.SessionInfo == nil || event.SessionInfo.App.Runtime != "goose" {
		t.Fatalf("runtime = %+v, want goose", event.SessionInfo)
	}
	if event.SessionInfo == nil || event.SessionInfo.App.MachineID != "machine-26" {
		t.Fatalf("machineID = %+v, want machine-26", event.SessionInfo)
	}
}

func TestAttachSessionUsesOpenCodeLocalRuntimeMetadataAndBroadcasts(t *testing.T) {
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

	publisher := &fakeAttachPublisher{machineID: "machine-3"}
	d := &Daemon{attachPublisher: publisher}

	resp, err := d.attachSession(context.Background(), control.AttachSessionRequest{
		SessionID: "ses-open-1",
		Runtime:   "opencode",
	})
	if err != nil {
		t.Fatalf("attachSession: %v", err)
	}
	if !resp.Broadcasted {
		t.Fatalf("Broadcasted = false, want true")
	}
	if resp.Runtime != "opencode" {
		t.Fatalf("runtime = %q, want opencode", resp.Runtime)
	}
	if resp.CWD != "/tmp/opencode-project" {
		t.Fatalf("cwd = %q, want /tmp/opencode-project", resp.CWD)
	}
	if resp.Title != "Attach this OpenCode session" {
		t.Fatalf("title = %q, want Attach this OpenCode session", resp.Title)
	}
	if len(publisher.events) != 1 {
		t.Fatalf("events = %d, want 1", len(publisher.events))
	}
	event := publisher.events[0]
	if event.SessionInfo == nil || event.SessionInfo.App.Runtime != "opencode" {
		t.Fatalf("runtime = %+v, want opencode", event.SessionInfo)
	}
	if event.SessionInfo == nil || event.SessionInfo.App.MachineID != "machine-3" {
		t.Fatalf("machineID = %+v, want machine-3", event.SessionInfo)
	}
}

func TestHandleAttachSessionRejectsNonPost(t *testing.T) {
	d := &Daemon{}

	req := httptest.NewRequest(http.MethodGet, "/remote/attach-session", nil)
	rec := httptest.NewRecorder()
	d.handleAttachSession(rec, req)

	if rec.Code != http.StatusMethodNotAllowed {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusMethodNotAllowed)
	}
}

func TestHandleAttachSessionReturnsServiceUnavailableWithoutActiveRelay(t *testing.T) {
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

	d := &Daemon{}
	body, err := json.Marshal(control.AttachSessionRequest{
		SessionID: "019d-session",
		Runtime:   "codex",
	})
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}
	req := httptest.NewRequest(
		http.MethodPost,
		"/remote/attach-session",
		bytes.NewReader(body),
	)
	rec := httptest.NewRecorder()
	d.handleAttachSession(rec, req)

	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusServiceUnavailable)
	}
}

func TestHandleAttachSessionMapsTranscriptNotFoundTo404(t *testing.T) {
	t.Setenv("CODEX_HOME", t.TempDir())
	d := &Daemon{attachPublisher: &fakeAttachPublisher{}}

	body, err := json.Marshal(control.AttachSessionRequest{
		SessionID: "missing",
		Runtime:   "codex",
	})
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}
	req := httptest.NewRequest(
		http.MethodPost,
		"/remote/attach-session",
		bytes.NewReader(body),
	)
	rec := httptest.NewRecorder()
	d.handleAttachSession(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusNotFound)
	}
}

func TestAttachSessionAllowsCWDOverrideWhenTranscriptMetadataIsMissing(t *testing.T) {
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

	publisher := &fakeAttachPublisher{}
	d := &Daemon{attachPublisher: publisher}

	resp, err := d.attachSession(context.Background(), control.AttachSessionRequest{
		SessionID: "019d-no-cwd",
		Runtime:   "codex",
		CWD:       "/tmp/override",
	})
	if err != nil {
		t.Fatalf("attachSession: %v", err)
	}
	if resp.CWD != "/tmp/override" {
		t.Fatalf("response cwd = %q, want /tmp/override", resp.CWD)
	}
	if publisher.events[0].SessionInfo == nil || publisher.events[0].SessionInfo.App.CWD != "/tmp/override" {
		t.Fatalf("broadcast cwd = %+v, want /tmp/override", publisher.events[0].SessionInfo)
	}
}

func TestHandleAttachSessionMapsNoActivePhoneTo409(t *testing.T) {
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

	d := &Daemon{attachPublisher: &fakeAttachPublisher{err: relayws.ErrNoActiveSession}}
	body, err := json.Marshal(control.AttachSessionRequest{
		SessionID: "019d-session",
		Runtime:   "codex",
	})
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}
	req := httptest.NewRequest(
		http.MethodPost,
		"/remote/attach-session",
		bytes.NewReader(body),
	)
	rec := httptest.NewRecorder()
	d.handleAttachSession(rec, req)

	if rec.Code != http.StatusConflict {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusConflict)
	}
}
