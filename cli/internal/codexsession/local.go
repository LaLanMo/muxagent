package codexsession

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

const LocalTranscriptSource = "codex_local_transcript"

var (
	ErrSessionNotFound    = errors.New("session not found in local codex transcript store")
	ErrMissingCWD         = errors.New("missing cwd for session attach")
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
	Timestamp string          `json:"timestamp"`
	Type      string          `json:"type"`
	Payload   json.RawMessage `json:"payload"`
}

type sessionMetaPayload struct {
	ID  string `json:"id"`
	CWD string `json:"cwd"`
}

type sessionIndexLine struct {
	ID         string `json:"id"`
	ThreadName string `json:"thread_name"`
	UpdatedAt  string `json:"updated_at"`
}

func ResolveLocalSession(sessionID string) (LocalMetadata, error) {
	sessionID = strings.TrimSpace(sessionID)
	if sessionID == "" {
		return LocalMetadata{}, ErrMissingSessionID
	}

	transcriptPath, err := transcriptPath(sessionID)
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

	title, updatedAt, err := parseSessionIndex(sessionID)
	if err != nil {
		return LocalMetadata{}, err
	}
	if strings.TrimSpace(title) != "" {
		meta.Title = strings.TrimSpace(title)
	}
	if meta.Title == "" {
		meta.Title = fallbackSessionTitle(transcriptPath, sessionID)
	}
	if !updatedAt.IsZero() {
		meta.UpdatedAt = updatedAt
	}
	if meta.UpdatedAt.IsZero() {
		if info, statErr := os.Stat(transcriptPath); statErr == nil {
			meta.UpdatedAt = info.ModTime().UTC()
		}
	}
	if meta.UpdatedAt.IsZero() && !meta.CreatedAt.IsZero() {
		meta.UpdatedAt = meta.CreatedAt
	}
	if meta.UpdatedAt.IsZero() {
		meta.UpdatedAt = time.Now().UTC()
	}
	meta.Source = LocalTranscriptSource
	return meta, nil
}

func transcriptPath(sessionID string) (string, error) {
	base, err := baseDir()
	if err != nil {
		return "", err
	}
	patterns := []string{
		filepath.Join(base, "sessions", "*", "*", "*", "*"+sessionID+".jsonl"),
		filepath.Join(base, "archived_sessions", "*"+sessionID+".jsonl"),
	}
	for _, pattern := range patterns {
		matches, err := filepath.Glob(pattern)
		if err != nil {
			return "", err
		}
		if len(matches) == 0 {
			continue
		}
		if len(matches) > 1 {
			return "", fmt.Errorf("%w: %q", ErrAmbiguousSessionID, sessionID)
		}
		return matches[0], nil
	}
	return "", nil
}

func baseDir() (string, error) {
	if root := strings.TrimSpace(os.Getenv("CODEX_HOME")); root != "" {
		return root, nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".codex"), nil
}

func parseTranscriptMetadata(path string, sessionID string) (LocalMetadata, error) {
	file, err := os.Open(path)
	if err != nil {
		return LocalMetadata{}, fmt.Errorf("open transcript: %w", err)
	}
	defer file.Close()

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
				if strings.TrimSpace(line.Type) == "session_meta" {
					var payload sessionMetaPayload
					if err := json.Unmarshal(line.Payload, &payload); err != nil {
						return LocalMetadata{}, fmt.Errorf("parse session_meta payload: %w", err)
					}
					if id := strings.TrimSpace(payload.ID); id == "" || id == sessionID {
						return LocalMetadata{
							SessionID:      sessionID,
							CWD:            strings.TrimSpace(payload.CWD),
							TranscriptPath: path,
							CreatedAt:      parseCodexTime(line.Timestamp),
						}, nil
					}
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
	return LocalMetadata{
		SessionID:      sessionID,
		TranscriptPath: path,
	}, nil
}

func parseSessionIndex(sessionID string) (string, time.Time, error) {
	base, err := baseDir()
	if err != nil {
		return "", time.Time{}, err
	}
	path := filepath.Join(base, "session_index.jsonl")
	file, err := os.Open(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return "", time.Time{}, nil
		}
		return "", time.Time{}, fmt.Errorf("open session index: %w", err)
	}
	defer file.Close()

	reader := bufio.NewReader(file)
	for {
		rawLine, err := reader.ReadString('\n')
		if len(rawLine) > 0 {
			raw := strings.TrimSpace(rawLine)
			if raw != "" {
				var line sessionIndexLine
				if err := json.Unmarshal([]byte(raw), &line); err != nil {
					return "", time.Time{}, fmt.Errorf("parse session index line: %w", err)
				}
				if strings.TrimSpace(line.ID) == sessionID {
					return strings.TrimSpace(line.ThreadName), parseCodexTime(line.UpdatedAt), nil
				}
			}
		}
		if err != nil {
			if errors.Is(err, io.EOF) {
				break
			}
			return "", time.Time{}, fmt.Errorf("scan session index: %w", err)
		}
	}
	return "", time.Time{}, nil
}

func fallbackSessionTitle(transcriptPath string, sessionID string) string {
	base := strings.TrimSuffix(filepath.Base(transcriptPath), filepath.Ext(transcriptPath))
	base = strings.TrimSpace(base)
	if base == "" {
		return sessionID
	}
	return base
}

func parseCodexTime(raw string) time.Time {
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
