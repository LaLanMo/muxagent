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
	runtimemanager "github.com/LaLanMo/muxagent/cli/internal/runtime/manager"
	"github.com/stretchr/testify/require"
)

const (
	geminiModeDefaultID = "default"
	geminiModePlanID    = "plan"
)

func TestGeminiRemoteControlEndToEnd(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping real Gemini integration test in short mode")
	}
	if os.Getenv("MUXAGENT_E2E_GEMINI") == "" {
		t.Skip("set MUXAGENT_E2E_GEMINI=1 to run the real Gemini integration test")
	}
	if _, err := exec.LookPath("gemini"); err != nil {
		t.Skipf("gemini not found on PATH: %v", err)
	}

	workdir := moduleRoot(t)
	cfg := config.Default()
	cfg.Runtimes = map[config.RuntimeID]config.RuntimeSettings{
		config.RuntimeGemini: {},
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
	geminiRuntime := findRuntimeInfo(runtimeList.Runtimes, string(config.RuntimeGemini))
	require.NotNil(t, geminiRuntime)
	require.Equal(t, "Gemini CLI", geminiRuntime.Label)
	require.Equal(t, geminiModeDefaultID, currentConfigValue(geminiRuntime.ConfigOptions, "mode"))

	createAny, errStr := client.rpcCreateSession(ctx, appwire.CreateSessionParams{
		CWD:            workdir,
		Runtime:        string(config.RuntimeGemini),
		PermissionMode: geminiModePlanID,
	})
	require.Empty(t, errStr)
	createResp, ok := createAny.(appwire.SessionCreateResult)
	require.True(t, ok)
	require.Equal(t, string(config.RuntimeGemini), createResp.App.Runtime)
	require.Equal(t, geminiModePlanID, currentConfigValue(createResp.ACP.ConfigOptions, "mode"))
	sessionID := createResp.ACP.SessionID
	require.NotEmpty(t, sessionID)

	originalModel := currentConfigValue(createResp.ACP.ConfigOptions, "model")
	require.NotEmpty(t, originalModel)
	targetModel := pickAlternateConfigValue(createResp.ACP.ConfigOptions, "model")
	require.NotEmpty(t, targetModel)
	if targetModel == originalModel {
		t.Skip("Gemini ACP did not expose an alternate model to verify switching")
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
		PermissionMode: geminiModeDefaultID,
	})
	require.Empty(t, errStr)
	modeEvent := waitForRuntimeEvent(t, rt.Events(), 30*time.Second, func(ev appwire.Event) bool {
		return ev.Type == appwire.EventModeChanged &&
			ev.SessionID == sessionID &&
			ev.ModeChanged != nil &&
			ev.ModeChanged.App.CurrentModeID == geminiModeDefaultID
	})
	require.Equal(t, geminiModeDefaultID, modeEvent.ModeChanged.App.CurrentModeID)

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
		Runtime:        string(config.RuntimeGemini),
		PermissionMode: geminiModePlanID,
		Model:          targetModel,
	})
	require.Empty(t, errStr)
	loadResp, ok := loadAny.(appwire.SessionLoadResult)
	require.True(t, ok)
	require.Equal(t, string(config.RuntimeGemini), loadResp.App.Runtime)
	require.Equal(t, geminiModePlanID, currentConfigValue(loadResp.ACP.ConfigOptions, "mode"))
	require.Equal(t, targetModel, currentConfigValue(loadResp.ACP.ConfigOptions, "model"))

	historyEvent := waitForRuntimeEvent(t, rt2.Events(), 30*time.Second, func(ev appwire.Event) bool {
		return ev.Type == appwire.EventHistoryComplete && ev.SessionID == sessionID
	})
	require.Equal(t, sessionID, historyEvent.SessionID)

	resolveAny, errStr := client2.rpcResolveSessions(ctx, appwire.ResolveSessionsParams{
		Runtime:    string(config.RuntimeGemini),
		SessionIDs: []string{sessionID},
	})
	require.Empty(t, errStr)
	resolveResp, ok := resolveAny.(appwire.SessionResolveResult)
	require.True(t, ok)
	require.Len(t, resolveResp.Sessions, 1)
	require.Equal(t, string(config.RuntimeGemini), resolveResp.Sessions[0].Runtime)
	require.Equal(t, workdir, resolveResp.Sessions[0].CWD)
	require.Equal(t, geminiModePlanID, currentConfigValue(resolveResp.Sessions[0].ConfigOptions, "mode"))
	require.Equal(t, targetModel, currentConfigValue(resolveResp.Sessions[0].ConfigOptions, "model"))
}
