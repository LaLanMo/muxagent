package opencodesession

import (
	"database/sql"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

const LocalStoreSource = "opencode_local_store"

var (
	ErrSessionNotFound  = errors.New("session not found in local opencode store")
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
		return LocalMetadata{}, fmt.Errorf("open opencode db: %w", err)
	}
	defer db.Close()

	var meta LocalMetadata
	var createdMS, updatedMS int64
	err = db.QueryRow(
		`SELECT id, directory, title, time_created, time_updated FROM session WHERE id = ?`,
		sessionID,
	).Scan(&meta.SessionID, &meta.CWD, &meta.Title, &createdMS, &updatedMS)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return LocalMetadata{}, ErrSessionNotFound
		}
		return LocalMetadata{}, fmt.Errorf("query opencode session: %w", err)
	}

	meta.SessionID = strings.TrimSpace(meta.SessionID)
	meta.CWD = strings.TrimSpace(meta.CWD)
	meta.Title = strings.TrimSpace(meta.Title)
	if meta.Title == "" {
		meta.Title = meta.SessionID
	}
	meta.CreatedAt = unixMillis(createdMS)
	meta.UpdatedAt = unixMillis(updatedMS)
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

func dbPath() (string, error) {
	root, err := dataDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(root, "opencode.db"), nil
}

func dataDir() (string, error) {
	if root := strings.TrimSpace(os.Getenv("XDG_DATA_HOME")); root != "" {
		return filepath.Join(root, "opencode"), nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".local", "share", "opencode"), nil
}

func unixMillis(value int64) time.Time {
	if value <= 0 {
		return time.Time{}
	}
	return time.UnixMilli(value).UTC()
}
