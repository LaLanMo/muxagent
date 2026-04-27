package daemon

import (
	"errors"
	"os"
	"path/filepath"
	"testing"

	"github.com/LaLanMo/muxagent/cli/internal/config"
)

func TestResolveLiveDaemonStateKeepsStateWhenPIDIsAlive(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)

	state := config.DaemonState{
		Address:    "127.0.0.1:12345",
		PID:        42,
		InstanceID: "instance-1",
	}
	if _, err := config.SaveState(state); err != nil {
		t.Fatalf("SaveState: %v", err)
	}

	wantErr := errors.New("probe timeout")
	_, reuse, err := resolveLiveDaemonState(func(config.DaemonState) error {
		return wantErr
	}, func(pid int) bool {
		return pid == state.PID
	})
	if !errors.Is(err, wantErr) {
		t.Fatalf("resolveLiveDaemonState error = %v, want %v", err, wantErr)
	}
	if reuse {
		t.Fatal("reuse = true, want false")
	}
	if _, err := config.LoadState(); err != nil {
		t.Fatalf("daemon state unexpectedly cleared: %v", err)
	}
}

func TestResolveLiveDaemonStateClearsStateWhenPIDIsDead(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)

	state := config.DaemonState{
		Address:    "127.0.0.1:12345",
		PID:        42,
		InstanceID: "instance-1",
	}
	if _, err := config.SaveState(state); err != nil {
		t.Fatalf("SaveState: %v", err)
	}
	lockPath, err := config.StateLockPath()
	if err != nil {
		t.Fatalf("StateLockPath: %v", err)
	}
	if err := os.WriteFile(lockPath, []byte("999999"), 0o600); err != nil {
		t.Fatalf("write lock: %v", err)
	}

	resolved, reuse, err := resolveLiveDaemonState(func(config.DaemonState) error {
		return errors.New("dial tcp: connection refused")
	}, func(int) bool {
		return false
	})
	if err != nil {
		t.Fatalf("resolveLiveDaemonState error: %v", err)
	}
	if reuse {
		t.Fatal("reuse = true, want false")
	}
	if resolved != (config.DaemonState{}) {
		t.Fatalf("resolved = %#v, want zero value", resolved)
	}
	statePath, err := config.StatePath()
	if err != nil {
		t.Fatalf("StatePath: %v", err)
	}
	if _, err := os.Stat(statePath); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("daemon state err = %v, want os.ErrNotExist", err)
	}
	if _, err := os.Stat(lockPath); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("daemon lock err = %v, want os.ErrNotExist", err)
	}
}

func TestDaemonEnsureLockPathUsesMuxagentStateDir(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)

	path, err := daemonEnsureLockPath()
	if err != nil {
		t.Fatalf("daemonEnsureLockPath: %v", err)
	}
	want := filepath.Join(home, ".muxagent", "daemon.ensure.lock")
	if path != want {
		t.Fatalf("path = %q, want %q", path, want)
	}
}
