package copilotsession

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const LocalSessionStateSource = "copilot_local_session_state"

var (
	ErrSessionNotFound  = errors.New("session not found in local copilot session state")
	ErrMissingSessionID = errors.New("missing session id")
)

type LocalMetadata struct {
	SessionID  string
	CWD        string
	Title      string
	EventsPath string
	Source     string
	CreatedAt  time.Time
	UpdatedAt  time.Time
}

type eventLine struct {
	Type      string          `json:"type"`
	Timestamp string          `json:"timestamp"`
	Data      json.RawMessage `json:"data"`
}

type sessionContext struct {
	CWD string `json:"cwd"`
}

type sessionStartData struct {
	SessionID string         `json:"sessionId"`
	StartTime string         `json:"startTime"`
	Context   sessionContext `json:"context"`
}

type sessionResumeData struct {
	ResumeTime string         `json:"resumeTime"`
	Context    sessionContext `json:"context"`
}

type userMessageData struct {
	Content string `json:"content"`
}

func ResolveLocalSession(sessionID string) (LocalMetadata, error) {
	sessionID = strings.TrimSpace(sessionID)
	if sessionID == "" {
		return LocalMetadata{}, ErrMissingSessionID
	}

	path, err := eventsPath(sessionID)
	if err != nil {
		return LocalMetadata{}, err
	}
	if _, err := os.Stat(path); err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return LocalMetadata{}, ErrSessionNotFound
		}
		return LocalMetadata{}, fmt.Errorf("stat copilot session state: %w", err)
	}

	meta, err := parseSessionMetadata(path, sessionID)
	if err != nil {
		return LocalMetadata{}, err
	}
	if strings.TrimSpace(meta.Title) == "" {
		meta.Title = sessionID
	}
	if meta.UpdatedAt.IsZero() {
		if info, statErr := os.Stat(path); statErr == nil {
			meta.UpdatedAt = info.ModTime().UTC()
		}
	}
	if meta.CreatedAt.IsZero() {
		meta.CreatedAt = meta.UpdatedAt
	}
	if meta.UpdatedAt.IsZero() {
		meta.UpdatedAt = time.Now().UTC()
	}
	if meta.CreatedAt.IsZero() {
		meta.CreatedAt = meta.UpdatedAt
	}
	meta.Source = LocalSessionStateSource
	return meta, nil
}

func eventsPath(sessionID string) (string, error) {
	base, err := baseDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(base, "session-state", strings.TrimSpace(sessionID), "events.jsonl"), nil
}

func baseDir() (string, error) {
	if root := strings.TrimSpace(os.Getenv("COPILOT_HOME")); root != "" {
		return root, nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".copilot"), nil
}

func parseSessionMetadata(path string, sessionID string) (LocalMetadata, error) {
	file, err := os.Open(path)
	if err != nil {
		return LocalMetadata{}, fmt.Errorf("open copilot session state: %w", err)
	}
	defer file.Close()

	meta := LocalMetadata{
		SessionID:  sessionID,
		EventsPath: path,
	}

	reader := bufio.NewReader(file)
	for {
		rawLine, err := reader.ReadString('\n')
		if len(rawLine) > 0 {
			raw := strings.TrimSpace(rawLine)
			if raw != "" {
				var line eventLine
				if err := json.Unmarshal([]byte(raw), &line); err != nil {
					return LocalMetadata{}, fmt.Errorf("parse copilot session line: %w", err)
				}
				if ts := parseCopilotTime(line.Timestamp); !ts.IsZero() && ts.After(meta.UpdatedAt) {
					meta.UpdatedAt = ts
					if meta.CreatedAt.IsZero() {
						meta.CreatedAt = ts
					}
				}
				switch strings.TrimSpace(line.Type) {
				case "session.start":
					if err := mergeSessionStart(&meta, line.Data); err != nil {
						return LocalMetadata{}, err
					}
				case "session.resume":
					if err := mergeSessionResume(&meta, line.Data); err != nil {
						return LocalMetadata{}, err
					}
				case "user.message":
					if meta.Title == "" {
						if err := mergeUserMessageTitle(&meta, line.Data); err != nil {
							return LocalMetadata{}, err
						}
					}
				}
			}
		}
		if err != nil {
			if errors.Is(err, io.EOF) {
				break
			}
			return LocalMetadata{}, fmt.Errorf("scan copilot session state: %w", err)
		}
	}

	return meta, nil
}

func mergeSessionStart(meta *LocalMetadata, raw json.RawMessage) error {
	var data sessionStartData
	if err := json.Unmarshal(raw, &data); err != nil {
		return fmt.Errorf("parse copilot session.start payload: %w", err)
	}
	if sessionID := strings.TrimSpace(data.SessionID); sessionID != "" {
		meta.SessionID = sessionID
	}
	if cwd := strings.TrimSpace(data.Context.CWD); cwd != "" {
		meta.CWD = cwd
	}
	if ts := parseCopilotTime(data.StartTime); !ts.IsZero() {
		if meta.CreatedAt.IsZero() || ts.Before(meta.CreatedAt) {
			meta.CreatedAt = ts
		}
		if ts.After(meta.UpdatedAt) {
			meta.UpdatedAt = ts
		}
	}
	return nil
}

func mergeSessionResume(meta *LocalMetadata, raw json.RawMessage) error {
	var data sessionResumeData
	if err := json.Unmarshal(raw, &data); err != nil {
		return fmt.Errorf("parse copilot session.resume payload: %w", err)
	}
	if cwd := strings.TrimSpace(data.Context.CWD); cwd != "" {
		meta.CWD = cwd
	}
	if ts := parseCopilotTime(data.ResumeTime); !ts.IsZero() {
		if meta.CreatedAt.IsZero() {
			meta.CreatedAt = ts
		}
		if ts.After(meta.UpdatedAt) {
			meta.UpdatedAt = ts
		}
	}
	return nil
}

func mergeUserMessageTitle(meta *LocalMetadata, raw json.RawMessage) error {
	var data userMessageData
	if err := json.Unmarshal(raw, &data); err != nil {
		return fmt.Errorf("parse copilot user.message payload: %w", err)
	}
	title := compactWhitespace(data.Content)
	if isControlOnlyTitle(title) {
		return nil
	}
	meta.Title = title
	return nil
}

func isControlOnlyTitle(title string) bool {
	title = strings.TrimSpace(title)
	if title == "" {
		return true
	}
	if strings.HasPrefix(title, "/") && !strings.Contains(title, " ") {
		return true
	}
	return false
}

func compactWhitespace(text string) string {
	return strings.Join(strings.Fields(strings.TrimSpace(text)), " ")
}

func parseCopilotTime(raw string) time.Time {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return time.Time{}
	}
	layouts := []string{time.RFC3339Nano, time.RFC3339}
	for _, layout := range layouts {
		if parsed, err := time.Parse(layout, raw); err == nil {
			return parsed.UTC()
		}
	}
	return time.Time{}
}
