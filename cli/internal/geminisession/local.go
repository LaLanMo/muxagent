package geminisession

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const LocalSessionStoreSource = "gemini_local_session_store"

var (
	ErrSessionNotFound  = errors.New("session not found in local gemini store")
	ErrMissingSessionID = errors.New("missing session id")
)

type LocalMetadata struct {
	SessionID   string
	CWD         string
	Title       string
	SessionPath string
	CreatedAt   time.Time
	UpdatedAt   time.Time
	Source      string
}

type sessionFile struct {
	SessionID   string           `json:"sessionId"`
	StartTime   string           `json:"startTime"`
	LastUpdated string           `json:"lastUpdated"`
	Messages    []sessionMessage `json:"messages"`
}

type sessionMessage struct {
	Type    string          `json:"type"`
	Content json.RawMessage `json:"content"`
}

type contentPart struct {
	Text string `json:"text"`
}

func ResolveLocalSession(sessionID string) (LocalMetadata, error) {
	sessionID = strings.TrimSpace(sessionID)
	if sessionID == "" {
		return LocalMetadata{}, ErrMissingSessionID
	}

	root, err := dataDir()
	if err != nil {
		return LocalMetadata{}, err
	}

	paths, err := filepath.Glob(filepath.Join(root, "tmp", "*", "chats", "*.json"))
	if err != nil {
		return LocalMetadata{}, fmt.Errorf("glob gemini sessions: %w", err)
	}

	var (
		best     LocalMetadata
		bestRank = -1
		found    bool
	)
	for _, path := range paths {
		meta, rank, ok := loadCandidate(path, sessionID)
		if !ok {
			continue
		}
		if !found || rank > bestRank || (rank == bestRank && meta.UpdatedAt.After(best.UpdatedAt)) {
			best = meta
			bestRank = rank
			found = true
		}
	}
	if !found {
		return LocalMetadata{}, ErrSessionNotFound
	}

	if best.Title == "" {
		best.Title = best.SessionID
	}
	if best.UpdatedAt.IsZero() {
		best.UpdatedAt = best.CreatedAt
	}
	if best.CreatedAt.IsZero() {
		best.CreatedAt = best.UpdatedAt
	}
	if best.UpdatedAt.IsZero() {
		best.UpdatedAt = time.Now().UTC()
	}
	if best.CreatedAt.IsZero() {
		best.CreatedAt = best.UpdatedAt
	}
	best.Source = LocalSessionStoreSource
	return best, nil
}

func loadCandidate(path string, sessionID string) (LocalMetadata, int, bool) {
	data, err := os.ReadFile(path)
	if err != nil {
		return LocalMetadata{}, 0, false
	}

	var session sessionFile
	if err := json.Unmarshal(data, &session); err != nil {
		return LocalMetadata{}, 0, false
	}
	if strings.TrimSpace(session.SessionID) != sessionID {
		return LocalMetadata{}, 0, false
	}

	meta := LocalMetadata{
		SessionID:   sessionID,
		SessionPath: path,
		Title:       firstMeaningfulUserMessage(session.Messages),
		CreatedAt:   parseGeminiTime(session.StartTime),
		UpdatedAt:   parseGeminiTime(session.LastUpdated),
	}
	meta.CWD = projectRoot(path)

	if info, err := os.Stat(path); err == nil {
		if meta.UpdatedAt.IsZero() {
			meta.UpdatedAt = info.ModTime().UTC()
		}
		if meta.CreatedAt.IsZero() {
			meta.CreatedAt = info.ModTime().UTC()
		}
	}

	rank := 0
	if meta.CWD != "" {
		rank += 10
	}
	if meta.Title != "" && meta.Title != meta.SessionID {
		rank++
	}
	return meta, rank, true
}

func dataDir() (string, error) {
	if root := strings.TrimSpace(os.Getenv("GEMINI_HOME")); root != "" {
		return root, nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".gemini"), nil
}

func projectRoot(sessionPath string) string {
	projectRootPath := filepath.Join(filepath.Dir(filepath.Dir(sessionPath)), ".project_root")
	data, err := os.ReadFile(projectRootPath)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}

func firstMeaningfulUserMessage(messages []sessionMessage) string {
	for _, message := range messages {
		if strings.TrimSpace(message.Type) != "user" {
			continue
		}
		text := compactWhitespace(messageText(message.Content))
		if isControlOnlyTitle(text) || isBootstrapPrompt(text) {
			continue
		}
		if text != "" {
			return text
		}
	}
	return ""
}

func messageText(raw json.RawMessage) string {
	raw = json.RawMessage(strings.TrimSpace(string(raw)))
	if len(raw) == 0 || string(raw) == "null" {
		return ""
	}

	var text string
	if err := json.Unmarshal(raw, &text); err == nil {
		return text
	}

	var parts []contentPart
	if err := json.Unmarshal(raw, &parts); err == nil {
		pieces := make([]string, 0, len(parts))
		for _, part := range parts {
			if item := compactWhitespace(part.Text); item != "" {
				pieces = append(pieces, item)
			}
		}
		return strings.Join(pieces, " ")
	}

	var part contentPart
	if err := json.Unmarshal(raw, &part); err == nil {
		return part.Text
	}
	return ""
}

func compactWhitespace(text string) string {
	return strings.Join(strings.Fields(strings.TrimSpace(text)), " ")
}

func isControlOnlyTitle(title string) bool {
	title = strings.TrimSpace(title)
	return title == ""
}

func isBootstrapPrompt(title string) bool {
	return strings.HasPrefix(title, "You are an AI agent that brings the power of Gemini directly into the terminal.")
}

func parseGeminiTime(raw string) time.Time {
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
