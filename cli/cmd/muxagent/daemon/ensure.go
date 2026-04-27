package daemon

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/LaLanMo/muxagent/cli/internal/config"
	"github.com/LaLanMo/muxagent/cli/internal/filelock"
	"github.com/spf13/cobra"
)

type ensureResult struct {
	Address               string `json:"address"`
	Token                 string `json:"token"`
	InstanceID            string `json:"instance_id"`
	PID                   int    `json:"pid"`
	StartedWithCLIVersion string `json:"started_with_cli_version"`
}

func newEnsureCmd() *cobra.Command {
	return &cobra.Command{
		Use:    "ensure",
		Short:  "Ensure the daemon is running",
		Hidden: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			lockPath, err := daemonEnsureLockPath()
			if err != nil {
				return err
			}
			lock, err := filelock.Acquire(lockPath, "muxagent daemon ensure is already running")
			if err != nil {
				return err
			}
			defer func() { _ = lock.Release() }()

			if state, reuse, err := resolveLiveDaemonState(probeDaemonState, isPIDAlive); err != nil {
				return fmt.Errorf("existing daemon unavailable: %w", err)
			} else if reuse {
				return writeEnsureResult(cmd.OutOrStdout(), state)
			}

			exe, err := os.Executable()
			if err != nil {
				return fmt.Errorf("resolve executable: %w", err)
			}

			logPath, logFile, err := openDaemonLogFile()
			if err != nil {
				return err
			}
			defer logFile.Close()

			child := exec.Command(exe, "daemon", "start-sync")
			child.Stdout = logFile
			child.Stderr = logFile
			child.Stdin = nil
			child.SysProcAttr = daemonSysProcAttr()

			if err := child.Start(); err != nil {
				return fmt.Errorf("start daemon process: %w", err)
			}
			childPID := child.Process.Pid
			_ = child.Process.Release()

			state, err := waitForDaemonReady(childPID, 10*time.Second)
			if err != nil {
				return fmt.Errorf("daemon failed to start: %w (see log: %s)", err, logPath)
			}
			return writeEnsureResult(cmd.OutOrStdout(), state)
		},
	}
}

func daemonEnsureLockPath() (string, error) {
	statePath, err := config.StatePath()
	if err != nil {
		return "", err
	}
	return filepath.Join(filepath.Dir(statePath), "daemon.ensure.lock"), nil
}

func resolveLiveDaemonState(
	probe func(config.DaemonState) error,
	pidAlive func(int) bool,
) (config.DaemonState, bool, error) {
	state, err := config.LoadState()
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return config.DaemonState{}, false, nil
		}
		return config.DaemonState{}, false, err
	}
	if strings.TrimSpace(state.Address) == "" {
		_ = config.ClearState()
		return config.DaemonState{}, false, nil
	}
	if probe == nil {
		probe = probeDaemonState
	}
	if pidAlive == nil {
		pidAlive = isPIDAlive
	}
	if err := probe(state); err != nil {
		if state.PID > 0 && pidAlive(state.PID) {
			return config.DaemonState{}, false, err
		}
		if clearErr := config.ClearState(); clearErr != nil {
			return config.DaemonState{}, false, clearErr
		}
		if cleanErr := config.CleanStaleLock(); cleanErr != nil {
			return config.DaemonState{}, false, cleanErr
		}
		return config.DaemonState{}, false, nil
	}
	return state, true, nil
}

func writeEnsureResult(w interface{ Write([]byte) (int, error) }, state config.DaemonState) error {
	token, err := state.GetToken()
	if err != nil {
		return fmt.Errorf("daemon token unavailable: %w", err)
	}
	return json.NewEncoder(w).Encode(ensureResult{
		Address:               state.Address,
		Token:                 token,
		InstanceID:            state.InstanceID,
		PID:                   state.PID,
		StartedWithCLIVersion: state.StartedWithCLIVersion,
	})
}
