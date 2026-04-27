package daemon

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/LaLanMo/muxagent/cli/internal/privdir"
	"github.com/google/uuid"
)

const localMachineIDFileName = "local-machine-id"

func localMachineID() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	path := filepath.Join(home, ".muxagent", localMachineIDFileName)
	if payload, err := os.ReadFile(path); err == nil {
		id := strings.TrimSpace(string(payload))
		if id != "" {
			return id, nil
		}
	} else if !os.IsNotExist(err) {
		return "", err
	}

	if err := privdir.Ensure(filepath.Dir(path)); err != nil {
		return "", err
	}
	id := "local-" + uuid.NewString()
	if err := os.WriteFile(path, []byte(id+"\n"), 0o600); err != nil {
		return "", fmt.Errorf("write local machine id: %w", err)
	}
	return id, nil
}
