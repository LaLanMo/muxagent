package config

import (
	"os"
	"path/filepath"
	"strings"
)

const TaskHomeEnv = "MUXAGENT_TASK_HOME"

func LegacyMuxagentRootDir() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".muxagent"), nil
}

// TaskHomeOverrideDir returns the repo-local task profile root when explicitly
// configured, without changing the legacy default ~/.muxagent behavior.
func TaskHomeOverrideDir() (string, bool, error) {
	override := strings.TrimSpace(os.Getenv(TaskHomeEnv))
	if override == "" {
		return "", false, nil
	}
	if filepath.IsAbs(override) {
		return filepath.Clean(override), true, nil
	}
	abs, err := filepath.Abs(override)
	if err != nil {
		return "", false, err
	}
	return filepath.Clean(abs), true, nil
}
