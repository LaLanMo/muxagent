package testutil

import (
	"bytes"
	"encoding/json"
	"log/slog"
	"strings"
	"testing"
)

func CaptureSlog(t testing.TB) *bytes.Buffer {
	t.Helper()

	buf := &bytes.Buffer{}
	old := slog.Default()
	slog.SetDefault(slog.New(slog.NewJSONHandler(buf, &slog.HandlerOptions{Level: slog.LevelDebug})))
	t.Cleanup(func() {
		slog.SetDefault(old)
	})
	return buf
}

func ParseLogEntries(t testing.TB, buf *bytes.Buffer) []map[string]any {
	t.Helper()

	lines := strings.Split(strings.TrimSpace(buf.String()), "\n")
	if len(lines) == 1 && lines[0] == "" {
		return nil
	}

	entries := make([]map[string]any, 0, len(lines))
	for _, line := range lines {
		if strings.TrimSpace(line) == "" {
			continue
		}
		var entry map[string]any
		if err := json.Unmarshal([]byte(line), &entry); err != nil {
			t.Fatalf("failed to unmarshal log line %q: %v", line, err)
		}
		entries = append(entries, entry)
	}
	return entries
}

func FindEntryByEvent(entries []map[string]any, event string) map[string]any {
	for _, entry := range entries {
		if entry["event"] == event {
			return entry
		}
	}
	return nil
}

func FindEntriesByEvent(entries []map[string]any, event string) []map[string]any {
	matches := make([]map[string]any, 0)
	for _, entry := range entries {
		if entry["event"] == event {
			matches = append(matches, entry)
		}
	}
	return matches
}
