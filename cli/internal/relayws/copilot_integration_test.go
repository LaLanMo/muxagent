package relayws

import (
	"context"
	"os"
	"os/exec"
	"strings"
	"testing"
	"time"

	"github.com/LaLanMo/muxagent/cli/internal/appwire"
	"github.com/LaLanMo/muxagent/cli/internal/config"
	"github.com/LaLanMo/muxagent/cli/internal/domain"
	runtimemanager "github.com/LaLanMo/muxagent/cli/internal/runtime/manager"
	"github.com/stretchr/testify/require"
)

const (
	copilotModeAgentID     = "https://agentclientprotocol.com/protocol/session-modes#agent"
	copilotModePlanID      = "https://agentclientprotocol.com/protocol/session-modes#plan"
	copilotModeAutopilotID = "https://agentclientprotocol.com/protocol/session-modes#autopilot"
)

func TestCopilotRemoteControlEndToEnd(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping real Copilot integration test in short mode")
	}
	if os.Getenv("MUXAGENT_E2E_COPILOT") == "" {
		t.Skip("set MUXAGENT_E2E_COPILOT=1 to run the real Copilot integration test")
	}
	if _, err := exec.LookPath("copilot"); err != nil {
		t.Skipf("copilot not found on PATH: %v", err)
	}

	workdir := moduleRoot(t)
	cfg := config.Default()
	cfg.Runtimes = map[config.RuntimeID]config.RuntimeSettings{
		config.RuntimeCopilot: {},
	}

	rt := runtimemanager.New(cfg)
	t.Cleanup(func() {
		_ = rt.Stop()
	})

	client := newRuntimeRPCClient(rt)
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()

	runtimeListAny, errStr := client.rpcRuntimeList(ctx)
	require.Empty(t, errStr)
	runtimeList, ok := runtimeListAny.(appwire.RuntimeListResult)
	require.True(t, ok)
	copilotRuntime := findRuntimeInfo(runtimeList.Runtimes, string(config.RuntimeCopilot))
	require.NotNil(t, copilotRuntime)
	require.Equal(t, "GitHub Copilot", copilotRuntime.Label)
	require.Equal(t, copilotModeAgentID, currentConfigValue(copilotRuntime.ConfigOptions, "mode"))

	createAny, errStr := client.rpcCreateSession(ctx, appwire.CreateSessionParams{
		CWD:            workdir,
		Runtime:        string(config.RuntimeCopilot),
		PermissionMode: copilotModePlanID,
	})
	require.Empty(t, errStr)
	createResp, ok := createAny.(appwire.SessionCreateResult)
	require.True(t, ok)
	require.Equal(t, string(config.RuntimeCopilot), createResp.App.Runtime)
	require.Equal(t, copilotModePlanID, currentConfigValue(createResp.ACP.ConfigOptions, "mode"))
	sessionID := createResp.ACP.SessionID
	require.NotEmpty(t, sessionID)

	originalModel := currentConfigValue(createResp.ACP.ConfigOptions, "model")
	require.NotEmpty(t, originalModel)
	targetModel := pickAlternateConfigValue(createResp.ACP.ConfigOptions, "model")
	require.NotEmpty(t, targetModel)
	if targetModel == originalModel {
		t.Skip("Copilot ACP did not expose an alternate model to verify switching")
	}

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

	_, errStr = client.rpcSetMode(ctx, appwire.SetModeParams{
		SessionID:      sessionID,
		PermissionMode: copilotModeAgentID,
	})
	require.Empty(t, errStr)
	modeEvent := waitForRuntimeEvent(t, rt.Events(), 30*time.Second, func(ev appwire.Event) bool {
		return ev.Type == appwire.EventModeChanged &&
			ev.SessionID == sessionID &&
			ev.ModeChanged != nil &&
			ev.ModeChanged.App.CurrentModeID == copilotModeAgentID
	})
	require.Equal(t, copilotModeAgentID, modeEvent.ModeChanged.App.CurrentModeID)

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

	time.Sleep(2 * time.Second)

	_ = rt.Stop()

	rt2 := runtimemanager.New(cfg)
	t.Cleanup(func() {
		_ = rt2.Stop()
	})
	client2 := newRuntimeRPCClient(rt2)

	loadAny, errStr := client2.rpcLoadSession(ctx, appwire.LoadSessionParams{
		SessionID:      sessionID,
		CWD:            workdir,
		Runtime:        string(config.RuntimeCopilot),
		PermissionMode: copilotModePlanID,
		Model:          targetModel,
	})
	require.Empty(t, errStr)
	loadResp, ok := loadAny.(appwire.SessionLoadResult)
	require.True(t, ok)
	require.Equal(t, string(config.RuntimeCopilot), loadResp.App.Runtime)
	require.Equal(t, copilotModePlanID, currentConfigValue(loadResp.ACP.ConfigOptions, "mode"))
	require.Equal(t, targetModel, currentConfigValue(loadResp.ACP.ConfigOptions, "model"))
	require.True(t, loadResp.App.Replay.Complete)
	require.NotEmpty(t, loadResp.App.Replay.Events)

	resolveAny, errStr := client2.rpcResolveSessions(ctx, appwire.ResolveSessionsParams{
		Runtime:    string(config.RuntimeCopilot),
		SessionIDs: []string{sessionID},
	})
	require.Empty(t, errStr)
	resolveResp, ok := resolveAny.(appwire.SessionResolveResult)
	require.True(t, ok)
	require.Len(t, resolveResp.Sessions, 1)
	require.Equal(t, string(config.RuntimeCopilot), resolveResp.Sessions[0].Runtime)
	require.Equal(t, copilotModePlanID, currentConfigValue(resolveResp.Sessions[0].ConfigOptions, "mode"))
	require.Equal(t, targetModel, currentConfigValue(resolveResp.Sessions[0].ConfigOptions, "model"))
}

func newRuntimeRPCClient(rt *runtimemanager.Manager) *Client {
	return &Client{
		runtime:       rt,
		sessionCWD:    map[string]string{},
		sessionStatus: map[string]domain.SessionStatus{},
	}
}
