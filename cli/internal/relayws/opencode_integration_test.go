package relayws

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/LaLanMo/muxagent/cli/internal/acpprotocol"
	"github.com/LaLanMo/muxagent/cli/internal/appwire"
	"github.com/LaLanMo/muxagent/cli/internal/config"
	"github.com/LaLanMo/muxagent/cli/internal/domain"
	runtimemanager "github.com/LaLanMo/muxagent/cli/internal/runtime/manager"
	"github.com/stretchr/testify/require"
)

func TestOpenCodeRemoteControlEndToEnd(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping real OpenCode integration test in short mode")
	}
	if os.Getenv("MUXAGENT_E2E_OPENCODE") == "" {
		t.Skip("set MUXAGENT_E2E_OPENCODE=1 to run the real OpenCode integration test")
	}
	if _, err := exec.LookPath("opencode"); err != nil {
		t.Skipf("opencode not found on PATH: %v", err)
	}

	workdir := moduleRoot(t)
	cfg := config.Default()
	cfg.Runtimes = map[config.RuntimeID]config.RuntimeSettings{
		config.RuntimeOpenCode: {},
	}
	rt := runtimemanager.New(cfg)
	t.Cleanup(func() {
		_ = rt.Stop()
	})

	client := &Client{
		runtime:       rt,
		sessionCWD:    map[string]string{},
		sessionStatus: map[string]domain.SessionStatus{},
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	runtimeListAny, errStr := client.rpcRuntimeList(ctx)
	require.Empty(t, errStr)
	runtimeList, ok := runtimeListAny.(appwire.RuntimeListResult)
	require.True(t, ok)
	openCodeRuntime := findRuntimeInfo(runtimeList.Runtimes, string(config.RuntimeOpenCode))
	require.NotNil(t, openCodeRuntime)
	require.Equal(t, "OpenCode", openCodeRuntime.Label)
	require.Equal(t, "build", currentConfigValue(openCodeRuntime.ConfigOptions, "mode"))

	createAny, errStr := client.rpcCreateSession(ctx, appwire.CreateSessionParams{
		CWD:            workdir,
		Runtime:        string(config.RuntimeOpenCode),
		PermissionMode: "plan",
	})
	require.Empty(t, errStr)
	createResp, ok := createAny.(appwire.SessionCreateResult)
	require.True(t, ok)
	require.Equal(t, string(config.RuntimeOpenCode), createResp.App.Runtime)
	require.Equal(t, "plan", currentConfigValue(createResp.ACP.ConfigOptions, "mode"))
	sessionID := createResp.ACP.SessionID
	require.NotEmpty(t, sessionID)

	originalModel := currentConfigValue(createResp.ACP.ConfigOptions, "model")
	require.NotEmpty(t, originalModel)
	targetModel := pickAlternateConfigValue(createResp.ACP.ConfigOptions, "model")
	require.NotEmpty(t, targetModel)

	_, errStr = client.rpcSetConfigOption(ctx, appwire.SetConfigOptionParams{
		SessionID: sessionID,
		ConfigID:  "model",
		Value:     targetModel,
	})
	require.Empty(t, errStr)
	modelEvent := waitForRuntimeEvent(t, rt.Events(), 30*time.Second, func(ev appwire.Event) bool {
		return ev.Type == appwire.EventModelChanged &&
			ev.SessionID == sessionID &&
			ev.ConfigChanged != nil &&
			ev.ConfigChanged.App.CurrentValue == targetModel
	})
	require.Equal(t, targetModel, modelEvent.ConfigChanged.App.CurrentValue)

	if targetModel != originalModel {
		_, errStr = client.rpcSetConfigOption(ctx, appwire.SetConfigOptionParams{
			SessionID: sessionID,
			ConfigID:  "model",
			Value:     originalModel,
		})
		require.Empty(t, errStr)
		restoreEvent := waitForRuntimeEvent(t, rt.Events(), 30*time.Second, func(ev appwire.Event) bool {
			return ev.Type == appwire.EventModelChanged &&
				ev.SessionID == sessionID &&
				ev.ConfigChanged != nil &&
				ev.ConfigChanged.App.CurrentValue == originalModel
		})
		require.Equal(t, originalModel, restoreEvent.ConfigChanged.App.CurrentValue)
	}

	_, errStr = client.rpcSetMode(ctx, appwire.SetModeParams{
		SessionID:      sessionID,
		PermissionMode: "build",
	})
	require.Empty(t, errStr)
	modeEvent := waitForRuntimeEvent(t, rt.Events(), 30*time.Second, func(ev appwire.Event) bool {
		return ev.Type == appwire.EventModeChanged &&
			ev.SessionID == sessionID &&
			ev.ModeChanged != nil &&
			ev.ModeChanged.App.CurrentModeID == "build"
	})
	require.Equal(t, "build", modeEvent.ModeChanged.App.CurrentModeID)

	promptAny, errStr := client.rpcPrompt(ctx, appwire.PromptParams{
		SessionID: sessionID,
		Text:      "Reply with exactly OK and nothing else.",
	})
	require.Empty(t, errStr)
	accepted, ok := promptAny.(appwire.AcceptedResult)
	require.True(t, ok)
	require.True(t, accepted.Accepted)

	okEvent := waitForRuntimeEvent(t, rt.Events(), 90*time.Second, func(ev appwire.Event) bool {
		return ev.Type == appwire.EventMessageDelta &&
			ev.SessionID == sessionID &&
			ev.MessagePart != nil &&
			ev.MessagePart.App.Role == appwire.MessageRoleAgent &&
			strings.Contains(ev.MessagePart.App.Delta, "OK")
	})
	require.Contains(t, okEvent.MessagePart.App.Delta, "OK")

	time.Sleep(1500 * time.Millisecond)

	loadAny, errStr := client.rpcLoadSession(ctx, appwire.LoadSessionParams{
		SessionID:      sessionID,
		CWD:            workdir,
		Runtime:        string(config.RuntimeOpenCode),
		PermissionMode: "build",
		Model:          originalModel,
	})
	require.Empty(t, errStr)
	loadResp, ok := loadAny.(appwire.SessionLoadResult)
	require.True(t, ok)
	require.Equal(t, string(config.RuntimeOpenCode), loadResp.App.Runtime)
	require.Equal(t, "build", currentConfigValue(loadResp.ACP.ConfigOptions, "mode"))
	require.Equal(t, originalModel, currentConfigValue(loadResp.ACP.ConfigOptions, "model"))
	require.True(t, loadResp.App.Replay.Complete)
	require.NotEmpty(t, loadResp.App.Replay.Events)

	resolveAny, errStr := client.rpcResolveSessions(ctx, appwire.ResolveSessionsParams{
		Runtime:    string(config.RuntimeOpenCode),
		SessionIDs: []string{sessionID},
	})
	require.Empty(t, errStr)
	resolveResp, ok := resolveAny.(appwire.SessionResolveResult)
	require.True(t, ok)
	require.Len(t, resolveResp.Sessions, 1)
	require.Equal(t, string(config.RuntimeOpenCode), resolveResp.Sessions[0].Runtime)
	require.Equal(t, "build", currentConfigValue(resolveResp.Sessions[0].ConfigOptions, "mode"))
}

func moduleRoot(t *testing.T) string {
	t.Helper()
	dir, err := os.Getwd()
	require.NoError(t, err)
	for {
		if _, err := os.Stat(filepath.Join(dir, "go.mod")); err == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			t.Fatal("could not find module root")
		}
		dir = parent
	}
}

func findRuntimeInfo(items []appwire.RuntimeInfo, id string) *appwire.RuntimeInfo {
	for i := range items {
		if items[i].ID == id {
			return &items[i]
		}
	}
	return nil
}

func currentConfigValue(options []acpprotocol.SessionConfigOption, category string) string {
	for _, option := range options {
		if option.Category != nil && *option.Category == category {
			return option.CurrentValue
		}
	}
	return ""
}

func pickAlternateConfigValue(options []acpprotocol.SessionConfigOption, category string) string {
	current := currentConfigValue(options, category)
	for _, option := range options {
		if option.Category == nil || *option.Category != category {
			continue
		}
		for _, value := range option.Options.Flatten() {
			if value.Value != "" && value.Value != current {
				return value.Value
			}
		}
		return current
	}
	return ""
}

func waitForRuntimeEvent(
	t *testing.T,
	events <-chan appwire.Event,
	timeout time.Duration,
	match func(appwire.Event) bool,
) appwire.Event {
	t.Helper()
	deadline := time.After(timeout)
	for {
		select {
		case ev, ok := <-events:
			if !ok {
				t.Fatal("runtime event channel closed before expected event")
			}
			if match(ev) {
				return ev
			}
		case <-deadline:
			t.Fatalf("timed out waiting for runtime event after %v", timeout)
		}
	}
}
