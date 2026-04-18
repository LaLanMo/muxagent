package goosesession

import (
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

const LocalStoreSource = "goose_local_store"

var (
	ErrSessionNotFound  = errors.New("session not found in local goose store")
	ErrMissingSessionID = errors.New("missing session id")
)

type LocalMetadata struct {
	SessionID string
	CWD       string
	Title     string
	CreatedAt time.Time
	UpdatedAt time.Time
	Source    string
}

type contentPart struct {
	Type string `json:"type"`
	Text string `json:"text"`
}

func ResolveLocalSession(sessionID string) (LocalMetadata, error) {
	sessionID = strings.TrimSpace(sessionID)
	if sessionID == "" {
		return LocalMetadata{}, ErrMissingSessionID
	}

	dbPath, err := dbPath()
	if err != nil {
		return LocalMetadata{}, err
	}
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return LocalMetadata{}, fmt.Errorf("open goose db: %w", err)
	}
	defer db.Close()

	meta, name, description, err := loadSessionMetadata(db, sessionID)
	if err != nil {
		return LocalMetadata{}, err
	}

	name = compactWhitespace(name)
	description = compactWhitespace(description)
	if isGenericSessionName(name) {
		name = ""
	}

	switch {
	case name != "":
		meta.Title = name
	case description != "":
		meta.Title = description
	default:
		prompt, err := firstUserPrompt(db, sessionID)
		if err != nil {
			return LocalMetadata{}, err
		}
		if prompt != "" {
			meta.Title = prompt
		} else {
			meta.Title = sessionID
		}
	}

	if meta.UpdatedAt.IsZero() {
		meta.UpdatedAt = meta.CreatedAt
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
	meta.Source = LocalStoreSource
	return meta, nil
}

func loadSessionMetadata(db *sql.DB, sessionID string) (LocalMetadata, string, string, error) {
	var (
		meta                   LocalMetadata
		name, description      string
		workingDir             string
		createdRaw, updatedRaw string
	)
	err := db.QueryRow(
		`SELECT id, name, description, working_dir, created_at, updated_at FROM sessions WHERE id = ?`,
		sessionID,
	).Scan(&meta.SessionID, &name, &description, &workingDir, &createdRaw, &updatedRaw)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return LocalMetadata{}, "", "", ErrSessionNotFound
		}
		return LocalMetadata{}, "", "", fmt.Errorf("query goose session: %w", err)
	}
	meta.CWD = strings.TrimSpace(workingDir)
	meta.CreatedAt = parseGooseTime(createdRaw)
	meta.UpdatedAt = parseGooseTime(updatedRaw)
	return meta, name, description, nil
}

func firstUserPrompt(db *sql.DB, sessionID string) (string, error) {
	var contentJSON string
	err := db.QueryRow(
		`SELECT content_json FROM messages WHERE session_id = ? AND role = 'user' ORDER BY created_timestamp ASC LIMIT 1`,
		sessionID,
	).Scan(&contentJSON)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return "", nil
		}
		return "", fmt.Errorf("query goose first user message: %w", err)
	}

	var parts []contentPart
	if err := json.Unmarshal([]byte(contentJSON), &parts); err != nil {
		return "", fmt.Errorf("parse goose message content_json: %w", err)
	}

	pieces := make([]string, 0, len(parts))
	for _, part := range parts {
		if strings.TrimSpace(part.Type) != "text" {
			continue
		}
		if text := compactWhitespace(part.Text); text != "" {
			pieces = append(pieces, text)
		}
	}
	return strings.Join(pieces, " "), nil
}

func dbPath() (string, error) {
	root, err := dataDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(root, "sessions", "sessions.db"), nil
}

func dataDir() (string, error) {
	if root := strings.TrimSpace(os.Getenv("XDG_DATA_HOME")); root != "" {
		return filepath.Join(root, "goose"), nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".local", "share", "goose"), nil
}

func compactWhitespace(text string) string {
	return strings.Join(strings.Fields(strings.TrimSpace(text)), " ")
}

func isGenericSessionName(name string) bool {
	switch compactWhitespace(name) {
	case "", "ACP Session", "CLI Session":
		return true
	default:
		return false
	}
}

func parseGooseTime(raw string) time.Time {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return time.Time{}
	}
	layouts := []string{
		time.RFC3339Nano,
		time.RFC3339,
		"2006-01-02 15:04:05",
	}
	for _, layout := range layouts {
		if parsed, err := time.Parse(layout, raw); err == nil {
			if layout == "2006-01-02 15:04:05" {
				return time.Date(parsed.Year(), parsed.Month(), parsed.Day(), parsed.Hour(), parsed.Minute(), parsed.Second(), parsed.Nanosecond(), time.UTC)
			}
			return parsed.UTC()
		}
	}
	return time.Time{}
}
