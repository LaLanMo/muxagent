package claudesession

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

const LocalTranscriptSource = "claude_local_transcript"

var (
	ErrSessionNotFound    = errors.New("session not found in local claude transcript store")
	ErrMissingSessionID   = errors.New("missing session id")
	ErrAmbiguousSessionID = errors.New("session id matched multiple transcripts")
)

type LocalMetadata struct {
	SessionID      string
	CWD            string
	Title          string
	TranscriptPath string
	Source         string
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

type transcriptLine struct {
	Type        string          `json:"type"`
	Timestamp   string          `json:"timestamp"`
	SessionID   string          `json:"sessionId"`
	SessionIDV1 string          `json:"session_id"`
	CWD         string          `json:"cwd"`
	IsMeta      bool            `json:"isMeta"`
	Message     json.RawMessage `json:"message"`
}

type transcriptMessage struct {
	Role    string `json:"role"`
	Content any    `json:"content"`
}

func ResolveLocalSession(sessionID string) (LocalMetadata, error) {
	sessionID = strings.TrimSpace(sessionID)
	if sessionID == "" {
		return LocalMetadata{}, ErrMissingSessionID
	}

	transcriptPath, err := findTranscriptPath(sessionID)
	if err != nil {
		return LocalMetadata{}, err
	}
	if transcriptPath == "" {
		return LocalMetadata{}, ErrSessionNotFound
	}

	meta, err := parseTranscriptMetadata(transcriptPath, sessionID)
	if err != nil {
		return LocalMetadata{}, err
	}
	if strings.TrimSpace(meta.Title) == "" {
		meta.Title = fallbackSessionTitle(transcriptPath, sessionID)
	}
	if meta.UpdatedAt.IsZero() {
		if info, statErr := os.Stat(transcriptPath); statErr == nil {
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
	meta.Source = LocalTranscriptSource
	return meta, nil
}

func TranscriptPath(workDir, sessionID string) (string, error) {
	base, err := baseDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(
		base,
		"projects",
		EscapeProjectDir(workDir),
		strings.TrimSpace(sessionID)+".jsonl",
	), nil
}

func EscapeProjectDir(workDir string) string {
	cleaned := filepath.Clean(strings.TrimSpace(workDir))
	return strings.ReplaceAll(cleaned, string(filepath.Separator), "-")
}

func findTranscriptPath(sessionID string) (string, error) {
	base, err := baseDir()
	if err != nil {
		return "", err
	}
	pattern := filepath.Join(base, "projects", "*", sessionID+".jsonl")
	matches, err := filepath.Glob(pattern)
	if err != nil {
		return "", err
	}
	if len(matches) == 0 {
		return "", nil
	}
	if len(matches) > 1 {
		return "", fmt.Errorf("%w: %q", ErrAmbiguousSessionID, sessionID)
	}
	return matches[0], nil
}

func baseDir() (string, error) {
	if root := strings.TrimSpace(os.Getenv("CLAUDE_CONFIG_DIR")); root != "" {
		return root, nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".claude"), nil
}

func parseTranscriptMetadata(path string, sessionID string) (LocalMetadata, error) {
	file, err := os.Open(path)
	if err != nil {
		return LocalMetadata{}, fmt.Errorf("open transcript: %w", err)
	}
	defer file.Close()

	meta := LocalMetadata{
		SessionID:      sessionID,
		TranscriptPath: path,
	}

	reader := bufio.NewReader(file)
	for {
		rawLine, err := reader.ReadString('\n')
		if len(rawLine) > 0 {
			raw := strings.TrimSpace(rawLine)
			if raw != "" {
				var line transcriptLine
				if err := json.Unmarshal([]byte(raw), &line); err != nil {
					return LocalMetadata{}, fmt.Errorf("parse transcript line: %w", err)
				}
				if meta.SessionID == "" {
					meta.SessionID = firstNonEmpty(
						strings.TrimSpace(line.SessionID),
						strings.TrimSpace(line.SessionIDV1),
						sessionID,
					)
				}
				if strings.TrimSpace(meta.CWD) == "" {
					meta.CWD = strings.TrimSpace(line.CWD)
				}
				if ts := parseClaudeTime(line.Timestamp); !ts.IsZero() {
					if meta.CreatedAt.IsZero() {
						meta.CreatedAt = ts
					}
					meta.UpdatedAt = ts
				}
				if meta.Title == "" {
					meta.Title = titleFromLine(line)
				}
			}
		}
		if err != nil {
			if errors.Is(err, io.EOF) {
				break
			}
			return LocalMetadata{}, fmt.Errorf("scan transcript: %w", err)
		}
	}

	if meta.SessionID == "" {
		meta.SessionID = sessionID
	}
	return meta, nil
}

func titleFromLine(line transcriptLine) string {
	if strings.TrimSpace(line.Type) != "user" || line.IsMeta || len(line.Message) == 0 {
		return ""
	}

	var msg transcriptMessage
	if err := json.Unmarshal(line.Message, &msg); err != nil {
		return ""
	}
	if role := strings.TrimSpace(msg.Role); role != "" && role != "user" {
		return ""
	}

	title := compactWhitespace(extractMessageText(msg.Content))
	if isControlOnlyTitle(title) {
		return ""
	}
	return title
}

func extractMessageText(content any) string {
	switch value := content.(type) {
	case string:
		return value
	case []any:
		parts := make([]string, 0, len(value))
		for _, item := range value {
			text := compactWhitespace(extractMessageText(item))
			if text != "" {
				parts = append(parts, text)
			}
		}
		return strings.Join(parts, " ")
	case map[string]any:
		kind := strings.TrimSpace(asString(value["type"]))
		switch kind {
		case "tool_result", "tool_use":
			return ""
		}
		if text := compactWhitespace(asString(value["text"])); text != "" {
			return text
		}
		if nested := compactWhitespace(extractMessageText(value["content"])); nested != "" {
			return nested
		}
	}
	return ""
}

func isControlOnlyTitle(title string) bool {
	title = strings.TrimSpace(title)
	if title == "" {
		return true
	}
	if strings.Contains(title, "<local-command-caveat>") ||
		strings.Contains(title, "<local-command-stdout>") ||
		strings.Contains(title, "<local-command-stderr>") ||
		strings.Contains(title, "<command-name>") ||
		strings.Contains(title, "<command-message>") ||
		strings.Contains(title, "<command-args>") {
		return true
	}
	if strings.HasPrefix(title, "/") && !strings.Contains(title, " ") {
		return true
	}
	return false
}

func fallbackSessionTitle(transcriptPath string, sessionID string) string {
	base := strings.TrimSuffix(filepath.Base(transcriptPath), filepath.Ext(transcriptPath))
	base = strings.TrimSpace(base)
	if base == "" {
		return sessionID
	}
	return base
}

func parseClaudeTime(raw string) time.Time {
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

func compactWhitespace(text string) string {
	return strings.Join(strings.Fields(strings.TrimSpace(text)), " ")
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			return trimmed
		}
	}
	return ""
}

func asString(value any) string {
	if s, ok := value.(string); ok {
		return s
	}
	return ""
}
