package sessionattach

import (
	"errors"
	"testing"
)

func TestRegistryResolveUnsupportedRuntime(t *testing.T) {
	registry := NewRegistry()

	_, err := registry.Resolve("gemini-cli", "session-1")
	if !errors.Is(err, ErrUnsupportedRuntime) {
		t.Fatalf("error = %v, want ErrUnsupportedRuntime", err)
	}
}

func TestRegistryResolveCodexMapsNotFoundToGenericSentinel(t *testing.T) {
	t.Setenv("CODEX_HOME", t.TempDir())

	registry := NewRegistry()

	_, err := registry.Resolve("codex", "missing")
	if !errors.Is(err, ErrSessionNotFound) {
		t.Fatalf("error = %v, want ErrSessionNotFound", err)
	}
}
