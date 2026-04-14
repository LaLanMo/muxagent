package appserver

import (
	"testing"

	"github.com/LaLanMo/muxagent/cli/internal/taskexecutor/codex"
	"github.com/LaLanMo/muxagent/cli/internal/taskexecutor/codexappserver"
	"github.com/LaLanMo/muxagent/cli/internal/taskexecutor/codexexec"
	"github.com/stretchr/testify/assert"
)

func TestNewCodexExecutorForAppServerDefaultsToExec(t *testing.T) {
	t.Setenv(codex.EnvExecutorMode, "")

	executor := newCodexExecutorForAppServer()

	_, ok := executor.(*codexexec.Executor)
	assert.True(t, ok)
}

func TestNewCodexExecutorForAppServerUsesAppServerWhenRequested(t *testing.T) {
	tests := []string{"appserver", "app-server", " AppServer "}
	for _, mode := range tests {
		t.Run(mode, func(t *testing.T) {
			t.Setenv(codex.EnvExecutorMode, mode)

			executor := newCodexExecutorForAppServer()

			_, ok := executor.(*codexappserver.Executor)
			assert.True(t, ok)
		})
	}
}

func TestNewCodexExecutorForAppServerFallsBackToExecOnUnknownMode(t *testing.T) {
	t.Setenv(codex.EnvExecutorMode, "mystery")

	executor := newCodexExecutorForAppServer()

	_, ok := executor.(*codexexec.Executor)
	assert.True(t, ok)
}
