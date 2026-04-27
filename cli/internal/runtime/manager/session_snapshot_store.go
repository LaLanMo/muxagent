package manager

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/LaLanMo/muxagent/cli/internal/acpprotocol"
	"github.com/LaLanMo/muxagent/cli/internal/privdir"
)

type sessionSnapshot struct {
	ConfigOptions []acpprotocol.SessionConfigOption `json:"configOptions,omitempty"`
	CWD           string                            `json:"cwd,omitempty"`
	Title         string                            `json:"title,omitempty"`
	UpdatedAt     time.Time                         `json:"updatedAt,omitempty"`
}

type sessionSnapshotStore struct {
	path      string
	mu        sync.RWMutex
	snapshots map[string]map[string]sessionSnapshot
}

func newSessionSnapshotStore(path string) *sessionSnapshotStore {
	return &sessionSnapshotStore{
		path:      path,
		snapshots: make(map[string]map[string]sessionSnapshot),
	}
}

func defaultSessionSnapshotStorePath() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".muxagent", "session.snapshots.json"), nil
}

func (s *sessionSnapshotStore) Load() error {
	s.mu.Lock()
	defer s.mu.Unlock()

	data, err := os.ReadFile(s.path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			s.snapshots = make(map[string]map[string]sessionSnapshot)
			return nil
		}
		return err
	}

	var snapshots map[string]map[string]sessionSnapshot
	if err := json.Unmarshal(data, &snapshots); err != nil {
		return err
	}
	if snapshots == nil {
		snapshots = make(map[string]map[string]sessionSnapshot)
	}
	s.snapshots = snapshots
	return nil
}

func (s *sessionSnapshotStore) Save() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.saveLocked()
}

func (s *sessionSnapshotStore) Get(
	runtimeID string,
	sessionID string,
) (sessionSnapshot, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	runtimeSnapshots, ok := s.snapshots[runtimeID]
	if !ok {
		return sessionSnapshot{}, false
	}
	snapshot, ok := runtimeSnapshots[sessionID]
	if !ok {
		return sessionSnapshot{}, false
	}
	return cloneSessionSnapshot(snapshot), true
}

func (s *sessionSnapshotStore) Ensure(
	runtimeID string,
	sessionID string,
) error {
	if runtimeID == "" || sessionID == "" {
		return nil
	}
	s.mu.Lock()
	defer s.mu.Unlock()

	runtimeSnapshots := s.ensureRuntimeSnapshotsLocked(runtimeID)
	if _, exists := runtimeSnapshots[sessionID]; exists {
		return nil
	}
	runtimeSnapshots[sessionID] = sessionSnapshot{UpdatedAt: time.Now().UTC()}
	return s.saveLocked()
}

func (s *sessionSnapshotStore) Put(
	runtimeID string,
	sessionID string,
	snapshot sessionSnapshot,
) error {
	if runtimeID == "" || sessionID == "" {
		return nil
	}
	s.mu.Lock()
	defer s.mu.Unlock()

	runtimeSnapshots := s.ensureRuntimeSnapshotsLocked(runtimeID)
	runtimeSnapshots[sessionID] = mergeSessionSnapshot(runtimeSnapshots[sessionID], snapshot)
	return s.saveLocked()
}

func (s *sessionSnapshotStore) Update(
	runtimeID string,
	sessionID string,
	update func(*sessionSnapshot) bool,
) error {
	if runtimeID == "" || sessionID == "" || update == nil {
		return nil
	}
	s.mu.Lock()
	defer s.mu.Unlock()

	runtimeSnapshots := s.ensureRuntimeSnapshotsLocked(runtimeID)
	current := runtimeSnapshots[sessionID]
	current.ConfigOptions = cloneConfigOptions(current.ConfigOptions)
	if !update(&current) {
		return nil
	}
	if current.UpdatedAt.IsZero() {
		current.UpdatedAt = time.Now().UTC()
	}
	runtimeSnapshots[sessionID] = mergeSessionSnapshot(runtimeSnapshots[sessionID], current)
	return s.saveLocked()
}

func (s *sessionSnapshotStore) ListRuntime(runtimeID string) map[string]sessionSnapshot {
	s.mu.RLock()
	defer s.mu.RUnlock()

	runtimeSnapshots, ok := s.snapshots[runtimeID]
	if !ok || len(runtimeSnapshots) == 0 {
		return nil
	}
	cloned := make(map[string]sessionSnapshot, len(runtimeSnapshots))
	for sessionID, snapshot := range runtimeSnapshots {
		cloned[sessionID] = cloneSessionSnapshot(snapshot)
	}
	return cloned
}

func (s *sessionSnapshotStore) All() map[string]map[string]sessionSnapshot {
	s.mu.RLock()
	defer s.mu.RUnlock()

	out := make(map[string]map[string]sessionSnapshot, len(s.snapshots))
	for runtimeID, runtimeSnapshots := range s.snapshots {
		cloned := make(map[string]sessionSnapshot, len(runtimeSnapshots))
		for sessionID, snapshot := range runtimeSnapshots {
			cloned[sessionID] = cloneSessionSnapshot(snapshot)
		}
		out[runtimeID] = cloned
	}
	return out
}

func (s *sessionSnapshotStore) ensureRuntimeSnapshotsLocked(
	runtimeID string,
) map[string]sessionSnapshot {
	runtimeSnapshots, ok := s.snapshots[runtimeID]
	if !ok {
		runtimeSnapshots = make(map[string]sessionSnapshot)
		s.snapshots[runtimeID] = runtimeSnapshots
	}
	return runtimeSnapshots
}

func (s *sessionSnapshotStore) saveLocked() error {
	data, err := json.MarshalIndent(s.snapshots, "", "  ")
	if err != nil {
		return err
	}
	dir := filepath.Dir(s.path)
	if err := privdir.Ensure(dir); err != nil {
		return err
	}
	tempFile, err := os.CreateTemp(dir, "session-snapshots-*.json")
	if err != nil {
		return err
	}
	tempPath := tempFile.Name()
	cleanup := true
	defer func() {
		if cleanup {
			_ = os.Remove(tempPath)
		}
	}()
	if _, err := tempFile.Write(data); err != nil {
		_ = tempFile.Close()
		return err
	}
	if err := tempFile.Close(); err != nil {
		return err
	}
	if err := os.Chmod(tempPath, 0o600); err != nil {
		return err
	}
	if err := os.Rename(tempPath, s.path); err != nil {
		return err
	}
	cleanup = false
	return nil
}

func cloneConfigOptions(
	options []acpprotocol.SessionConfigOption,
) []acpprotocol.SessionConfigOption {
	if len(options) == 0 {
		return nil
	}
	data, err := json.Marshal(options)
	if err != nil {
		return append([]acpprotocol.SessionConfigOption(nil), options...)
	}
	var cloned []acpprotocol.SessionConfigOption
	if err := json.Unmarshal(data, &cloned); err != nil {
		return append([]acpprotocol.SessionConfigOption(nil), options...)
	}
	return cloned
}

func cloneSessionSnapshot(snapshot sessionSnapshot) sessionSnapshot {
	return sessionSnapshot{
		ConfigOptions: cloneConfigOptions(snapshot.ConfigOptions),
		CWD:           snapshot.CWD,
		Title:         snapshot.Title,
		UpdatedAt:     normalizeSnapshotUpdatedAt(snapshot.UpdatedAt),
	}
}

func mergeSessionSnapshot(existing sessionSnapshot, incoming sessionSnapshot) sessionSnapshot {
	merged := cloneSessionSnapshot(incoming)
	if len(merged.ConfigOptions) == 0 && len(existing.ConfigOptions) > 0 {
		merged.ConfigOptions = cloneConfigOptions(existing.ConfigOptions)
	}
	if merged.CWD == "" {
		merged.CWD = existing.CWD
	}
	if merged.Title == "" {
		merged.Title = existing.Title
	}
	if merged.UpdatedAt.IsZero() {
		merged.UpdatedAt = normalizeSnapshotUpdatedAt(existing.UpdatedAt)
	}
	return merged
}

func normalizeSnapshotUpdatedAt(value time.Time) time.Time {
	if value.IsZero() {
		return time.Time{}
	}
	return value.UTC()
}
