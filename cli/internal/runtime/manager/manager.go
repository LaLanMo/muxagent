package manager

import (
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/LaLanMo/muxagent/cli/internal/acpbin"
	"github.com/LaLanMo/muxagent/cli/internal/acpprotocol"
	"github.com/LaLanMo/muxagent/cli/internal/appwire"
	"github.com/LaLanMo/muxagent/cli/internal/codexbin"
	"github.com/LaLanMo/muxagent/cli/internal/config"
	"github.com/LaLanMo/muxagent/cli/internal/domain"
	"github.com/LaLanMo/muxagent/cli/internal/runtime"
	"github.com/LaLanMo/muxagent/cli/internal/runtime/acp"
)

const (
	copilotModeAgent     = "https://agentclientprotocol.com/protocol/session-modes#agent"
	copilotModePlan      = "https://agentclientprotocol.com/protocol/session-modes#plan"
	copilotModeAutopilot = "https://agentclientprotocol.com/protocol/session-modes#autopilot"

	geminiModeDefault  = "default"
	geminiModeAutoEdit = "autoEdit"
	geminiModeYolo     = "yolo"
	geminiModePlan     = "plan"

	gooseModeAuto         = "auto"
	gooseModeApprove      = "approve"
	gooseModeSmartApprove = "smart_approve"
	gooseModeChat         = "chat"
)

type RuntimeInfo struct {
	ID            string                            `json:"id"`
	Label         string                            `json:"label"`
	Ready         bool                              `json:"ready"`
	ConfigOptions []acpprotocol.SessionConfigOption `json:"configOptions,omitempty"`
}

type Manager struct {
	cfg config.Config

	mu             sync.RWMutex
	runtimes       map[config.RuntimeID]*managedRuntime
	sessionRuntime map[string]config.RuntimeID
	snapshotStore  *sessionSnapshotStore

	events    chan appwire.Event
	closeOnce sync.Once
	done      chan struct{}
}

type managedRuntime struct {
	id       config.RuntimeID
	settings config.RuntimeSettings

	mu     sync.Mutex
	client runtime.Client
}

func New(cfg config.Config) *Manager {
	runtimes := make(map[config.RuntimeID]*managedRuntime, len(cfg.Runtimes))
	for id, settings := range cfg.Runtimes {
		if !supportsManagedRuntime(id) {
			continue
		}
		runtimes[id] = &managedRuntime{
			id:       id,
			settings: settings,
		}
	}
	sessionRuntime := make(map[string]config.RuntimeID)
	var snapshotStore *sessionSnapshotStore
	if storePath, err := defaultSessionSnapshotStorePath(); err != nil {
		log.Printf("[runtime] session snapshot store path unavailable: %v", err)
	} else {
		snapshotStore = newSessionSnapshotStore(storePath)
		if err := snapshotStore.Load(); err != nil {
			log.Printf("[runtime] session snapshot store load failed: %v", err)
		} else {
			for runtimeID, runtimeSnapshots := range snapshotStore.All() {
				rid := config.RuntimeID(strings.TrimSpace(runtimeID))
				if rid == "" {
					continue
				}
				for sessionID := range runtimeSnapshots {
					if sessionID == "" {
						continue
					}
					if _, exists := sessionRuntime[sessionID]; exists {
						continue
					}
					sessionRuntime[sessionID] = rid
				}
			}
		}
	}
	return &Manager{
		cfg:            cfg,
		runtimes:       runtimes,
		sessionRuntime: sessionRuntime,
		snapshotStore:  snapshotStore,
		events:         make(chan appwire.Event, 512),
		done:           make(chan struct{}),
	}
}

func (m *Manager) Stop() error {
	var firstErr error
	m.closeOnce.Do(func() {
		close(m.done)

		m.mu.RLock()
		runtimes := make([]*managedRuntime, 0, len(m.runtimes))
		for _, rt := range m.runtimes {
			runtimes = append(runtimes, rt)
		}
		m.mu.RUnlock()

		for _, rt := range runtimes {
			rt.mu.Lock()
			client := rt.client
			rt.client = nil
			rt.mu.Unlock()
			if client != nil {
				if err := client.Stop(); err != nil && firstErr == nil {
					firstErr = err
				}
			}
		}

		close(m.events)
	})
	return firstErr
}

func (m *Manager) Events() <-chan appwire.Event {
	return m.events
}

func (m *Manager) RuntimeList() []RuntimeInfo {
	type pair struct {
		id   config.RuntimeID
		info RuntimeInfo
	}
	items := make([]pair, 0, len(m.runtimes))
	for id := range m.runtimes {
		settings := m.runtimes[id].settings
		items = append(items, pair{
			id: id,
			info: RuntimeInfo{
				ID:            string(id),
				Label:         runtimeLabel(id),
				Ready:         runtimeReady(id, settings),
				ConfigOptions: runtimeConfigOptions(id),
			},
		})
	}

	sort.Slice(items, func(i, j int) bool {
		return items[i].info.Label < items[j].info.Label
	})

	out := make([]RuntimeInfo, 0, len(items))
	for _, item := range items {
		out = append(out, item.info)
	}
	return out
}

func (m *Manager) NewSession(
	ctx context.Context,
	runtimeID string,
	cwd string,
	permissionMode string,
) (string, string, acpprotocol.NewSessionResponse, error) {
	if strings.TrimSpace(runtimeID) == "" {
		return "", "", acpprotocol.NewSessionResponse{}, fmt.Errorf("missing runtime")
	}
	client, rid, err := m.ensureRuntime(ctx, runtimeID, cwd)
	if err != nil {
		return "", "", acpprotocol.NewSessionResponse{}, err
	}
	resp, err := client.NewSession(ctx, cwd, permissionMode)
	if err != nil {
		if shouldRetryRuntimeCall(client, err) {
			m.retireRuntimeClient(rid, client)
			retryClient, _, retryErr := m.ensureRuntime(ctx, string(rid), cwd)
			if retryErr != nil {
				return "", "", acpprotocol.NewSessionResponse{}, fmt.Errorf(
					"retired stale runtime after %v; restart failed: %w",
					err,
					retryErr,
				)
			}
			resp, err = retryClient.NewSession(ctx, cwd, permissionMode)
			if err != nil && shouldRetryRuntimeCall(retryClient, err) {
				m.retireRuntimeClient(rid, retryClient)
			}
		}
		if err != nil {
			return "", "", acpprotocol.NewSessionResponse{}, err
		}
	}
	resp.ConfigOptions = m.enrichSessionConfigOptions(
		rid,
		resp.SessionID,
		resp.ConfigOptions,
		permissionMode,
	)
	m.setSessionRuntime(resp.SessionID, rid)
	m.persistSessionSnapshot(resp.SessionID, rid, cwd, resp.ConfigOptions, time.Now().UTC())
	return resp.SessionID, string(rid), resp, nil
}

func (m *Manager) LoadSession(
	ctx context.Context,
	runtimeID string,
	sessionID string,
	cwd string,
	permissionMode string,
	model string,
) (string, acpprotocol.LoadSessionResponse, error) {
	rid := m.resolveRuntimeID(sessionID, runtimeID)
	if rid == "" {
		return "", acpprotocol.LoadSessionResponse{}, fmt.Errorf("missing runtime")
	}
	client, rid, err := m.ensureRuntime(ctx, string(rid), cwd)
	if err != nil {
		return "", acpprotocol.LoadSessionResponse{}, err
	}
	resp, err := client.LoadSession(ctx, sessionID, cwd, permissionMode, model)
	if err != nil {
		if shouldRetryRuntimeCall(client, err) {
			m.retireRuntimeClient(rid, client)
			retryClient, _, retryErr := m.ensureRuntime(ctx, string(rid), cwd)
			if retryErr != nil {
				return "", acpprotocol.LoadSessionResponse{}, fmt.Errorf(
					"retired stale runtime after %v; restart failed: %w",
					err,
					retryErr,
				)
			}
			resp, err = retryClient.LoadSession(ctx, sessionID, cwd, permissionMode, model)
			if err != nil && shouldRetryRuntimeCall(retryClient, err) {
				m.retireRuntimeClient(rid, retryClient)
			}
		}
		if err != nil {
			return "", acpprotocol.LoadSessionResponse{}, err
		}
	}
	resp.ConfigOptions = m.enrichSessionConfigOptions(
		rid,
		sessionID,
		resp.ConfigOptions,
		permissionMode,
	)
	m.setSessionRuntime(sessionID, rid)
	m.persistSessionSnapshot(sessionID, rid, cwd, resp.ConfigOptions)
	return string(rid), resp, nil
}

type scopedLoadClient interface {
	LoadSessionScoped(ctx context.Context, sessionID, cwd, permissionMode, model string) (acpprotocol.LoadSessionResponse, []appwire.Event, error)
}

func (m *Manager) LoadSessionScoped(
	ctx context.Context,
	runtimeID string,
	sessionID string,
	cwd string,
	permissionMode string,
	model string,
) (string, acpprotocol.LoadSessionResponse, []appwire.Event, error) {
	rid := m.resolveRuntimeID(sessionID, runtimeID)
	if rid == "" {
		return "", acpprotocol.LoadSessionResponse{}, nil, fmt.Errorf("missing runtime")
	}
	client, rid, err := m.ensureRuntime(ctx, string(rid), cwd)
	if err != nil {
		return "", acpprotocol.LoadSessionResponse{}, nil, err
	}

	var resp acpprotocol.LoadSessionResponse
	var events []appwire.Event
	if scoped, ok := client.(scopedLoadClient); ok {
		resp, events, err = scoped.LoadSessionScoped(ctx, sessionID, cwd, permissionMode, model)
	} else {
		resp, err = client.LoadSession(ctx, sessionID, cwd, permissionMode, model)
	}
	if err != nil {
		if shouldRetryRuntimeCall(client, err) {
			m.retireRuntimeClient(rid, client)
			retryClient, _, retryErr := m.ensureRuntime(ctx, string(rid), cwd)
			if retryErr != nil {
				return "", acpprotocol.LoadSessionResponse{}, nil, fmt.Errorf(
					"retired stale runtime after %v; restart failed: %w",
					err,
					retryErr,
				)
			}
			events = nil
			if scoped, ok := retryClient.(scopedLoadClient); ok {
				resp, events, err = scoped.LoadSessionScoped(ctx, sessionID, cwd, permissionMode, model)
			} else {
				resp, err = retryClient.LoadSession(ctx, sessionID, cwd, permissionMode, model)
			}
			if err != nil && shouldRetryRuntimeCall(retryClient, err) {
				m.retireRuntimeClient(rid, retryClient)
			}
		}
		if err != nil {
			return "", acpprotocol.LoadSessionResponse{}, nil, err
		}
	}
	resp.ConfigOptions = m.enrichSessionConfigOptions(
		rid,
		sessionID,
		resp.ConfigOptions,
		permissionMode,
	)
	m.setSessionRuntime(sessionID, rid)
	m.persistSessionSnapshot(sessionID, rid, cwd, resp.ConfigOptions)
	return string(rid), resp, events, nil
}

// ResolveSessions returns summaries for explicitly requested sessionIDs only.
func (m *Manager) ResolveSessions(
	ctx context.Context,
	runtimeID string,
	sessionIDs []string,
) ([]domain.SessionSummary, error) {
	targets := compactSessionIDs(sessionIDs)
	if len(targets) == 0 {
		return nil, nil
	}
	if runtimeID != "" {
		return m.resolveSessionsForRuntime(
			ctx,
			config.RuntimeID(runtimeID),
			targets,
		)
	}

	seen := make(map[string]struct{}, len(targets))
	list := make([]domain.SessionSummary, 0)
	for _, rid := range m.configuredRuntimeIDs() {
		sessions, err := m.resolveSessionsForRuntime(ctx, rid, targets)
		if err != nil {
			log.Printf("[runtime] resolve list %s failed: %v", rid, err)
			continue
		}
		for _, session := range sessions {
			if _, ok := seen[session.SessionID]; ok {
				continue
			}
			seen[session.SessionID] = struct{}{}
			list = append(list, session)
		}
	}
	return list, nil
}

func (m *Manager) ListSessions(
	ctx context.Context,
	runtimeID string,
	limit int,
) ([]domain.SessionSummary, error) {
	if runtimeID != "" {
		sessions, err := m.listSessionsForRuntime(ctx, config.RuntimeID(runtimeID))
		if err != nil {
			return nil, err
		}
		return limitSessionSummaries(sessions, limit), nil
	}

	seen := map[string]struct{}{}
	list := make([]domain.SessionSummary, 0)
	for _, rid := range m.configuredRuntimeIDs() {
		sessions, err := m.listSessionsForRuntime(ctx, rid)
		if err != nil {
			log.Printf("[runtime] session list %s failed: %v", rid, err)
			continue
		}
		for _, session := range sessions {
			if session.SessionID == "" {
				continue
			}
			if _, ok := seen[session.SessionID]; ok {
				continue
			}
			seen[session.SessionID] = struct{}{}
			list = append(list, session)
		}
	}
	sortSessionSummaries(list)
	return limitSessionSummaries(list, limit), nil
}

func (m *Manager) listSessionsForRuntime(
	ctx context.Context,
	rid config.RuntimeID,
) ([]domain.SessionSummary, error) {
	if rid == "" {
		return nil, nil
	}
	client, _, err := m.ensureRuntime(ctx, string(rid), "")
	if err != nil {
		snapshots := m.snapshotRuntimeSessionSummaries(rid)
		if len(snapshots) > 0 {
			return snapshots, nil
		}
		return nil, err
	}

	sessions, err := client.ListSessions(ctx, "")
	if err == nil {
		return m.mergeListedSessionsWithSnapshots(sessions, rid), nil
	}
	if isSessionListUnsupported(err) {
		return m.snapshotRuntimeSessionSummaries(rid), nil
	}
	if !shouldRetryRuntimeCall(client, err) {
		snapshots := m.snapshotRuntimeSessionSummaries(rid)
		if len(snapshots) > 0 {
			return snapshots, nil
		}
		return nil, err
	}

	m.retireRuntimeClient(rid, client)
	client, _, retryErr := m.ensureRuntime(ctx, string(rid), "")
	if retryErr != nil {
		snapshots := m.snapshotRuntimeSessionSummaries(rid)
		if len(snapshots) > 0 {
			return snapshots, nil
		}
		return nil, fmt.Errorf(
			"retired stale runtime after %v; restart failed: %w",
			err,
			retryErr,
		)
	}
	sessions, err = client.ListSessions(ctx, "")
	if err != nil {
		if isSessionListUnsupported(err) {
			return m.snapshotRuntimeSessionSummaries(rid), nil
		}
		snapshots := m.snapshotRuntimeSessionSummaries(rid)
		if len(snapshots) > 0 {
			return snapshots, nil
		}
		return nil, err
	}
	return m.mergeListedSessionsWithSnapshots(sessions, rid), nil
}

func (m *Manager) resolveSessionsForRuntime(
	ctx context.Context,
	rid config.RuntimeID,
	sessionIDs []string,
) ([]domain.SessionSummary, error) {
	if rid == "" || len(sessionIDs) == 0 {
		return nil, nil
	}
	client, _, err := m.ensureRuntime(ctx, string(rid), "")
	if err != nil {
		return nil, err
	}

	sessions, err := client.ListSessions(ctx, "")
	if err == nil {
		return m.mergeResolvedSessionsWithSnapshots(sessions, rid, sessionIDs), nil
	}
	if isSessionListUnsupported(err) {
		return m.snapshotSessionSummaries(rid, sessionIDs), nil
	}
	if !shouldRetryRuntimeCall(client, err) {
		return nil, err
	}

	m.retireRuntimeClient(rid, client)
	client, _, retryErr := m.ensureRuntime(ctx, string(rid), "")
	if retryErr != nil {
		return nil, fmt.Errorf(
			"retired stale runtime after %v; restart failed: %w",
			err,
			retryErr,
		)
	}
	sessions, err = client.ListSessions(ctx, "")
	if err != nil {
		if isSessionListUnsupported(err) {
			return m.snapshotSessionSummaries(rid, sessionIDs), nil
		}
		return nil, err
	}
	return m.mergeResolvedSessionsWithSnapshots(sessions, rid, sessionIDs), nil
}

func isSessionListUnsupported(err error) bool {
	return acp.IsMethodNotFoundError(err)
}

func (m *Manager) Prompt(
	ctx context.Context,
	sessionID string,
	content []domain.ContentBlock,
) (string, *domain.PromptUsage, error) {
	client, rid, err := m.runtimeForSession(ctx, sessionID)
	if err != nil {
		return "", nil, err
	}
	stopReason, usage, err := client.Prompt(ctx, sessionID, content)
	if err == nil {
		return stopReason, usage, nil
	}

	if shouldRetryRuntimeCall(client, err) {
		snapshot, hasSnapshot := m.sessionSnapshot(rid, sessionID)
		m.retireRuntimeClient(rid, client)
		retryClient, _, retryErr := m.ensureRuntime(ctx, string(rid), snapshot.CWD)
		if retryErr != nil {
			return "", nil, fmt.Errorf(
				"retired stale runtime after %v; restart failed: %w",
				err,
				retryErr,
			)
		}
		if loadErr := m.loadPromptSession(ctx, retryClient, rid, sessionID, snapshot, hasSnapshot); loadErr != nil {
			return "", nil, fmt.Errorf("reload session before prompt after stale runtime: %w", loadErr)
		}
		stopReason, usage, err = retryClient.Prompt(ctx, sessionID, content)
		if err != nil && shouldRetryRuntimeCall(retryClient, err) {
			m.retireRuntimeClient(rid, retryClient)
		}
		return stopReason, usage, err
	}

	if isSessionUnavailableForPrompt(err) {
		snapshot, hasSnapshot := m.sessionSnapshot(rid, sessionID)
		if loadErr := m.loadPromptSession(ctx, client, rid, sessionID, snapshot, hasSnapshot); loadErr != nil {
			return "", nil, fmt.Errorf("reload session before prompt: %w", loadErr)
		}
		return client.Prompt(ctx, sessionID, content)
	}

	return "", nil, err
}

func (m *Manager) Cancel(ctx context.Context, sessionID string) error {
	client, _, err := m.runtimeForSession(ctx, sessionID)
	if err != nil {
		return err
	}
	return client.Cancel(ctx, sessionID)
}

func (m *Manager) SetMode(ctx context.Context, sessionID string, modeID string) error {
	client, _, err := m.runtimeForSession(ctx, sessionID)
	if err != nil {
		return err
	}
	if err := client.SetMode(ctx, sessionID, modeID); err != nil {
		return err
	}
	m.updateSessionSnapshot(sessionID, func(snapshot *sessionSnapshot) bool {
		next, changed := updateModeConfigCurrentValue(snapshot.ConfigOptions, modeID)
		if !changed {
			return false
		}
		snapshot.ConfigOptions = next
		return true
	})
	return nil
}

func (m *Manager) SetConfigOption(ctx context.Context, sessionID string, configID string, value string) error {
	client, _, err := m.runtimeForSession(ctx, sessionID)
	if err != nil {
		return err
	}
	if err := client.SetConfigOption(ctx, sessionID, configID, value); err != nil {
		return err
	}
	m.updateSessionSnapshot(sessionID, func(snapshot *sessionSnapshot) bool {
		next, changed := updateConfigOptionCurrentValue(
			snapshot.ConfigOptions,
			configID,
			value,
		)
		if !changed {
			return false
		}
		snapshot.ConfigOptions = next
		return true
	})
	return nil
}

func (m *Manager) ReplyPermission(ctx context.Context, sessionID string, requestID string, optionID string) error {
	client, _, err := m.runtimeForSession(ctx, sessionID)
	if err != nil {
		return err
	}
	return client.ReplyPermission(ctx, sessionID, requestID, optionID)
}

func (m *Manager) PendingApprovals() []domain.ApprovalRequest {
	clients := m.startedClients()
	if len(clients) == 0 {
		return nil
	}
	out := make([]domain.ApprovalRequest, 0)
	for _, client := range clients {
		type pendingApprovals interface {
			PendingApprovals() []domain.ApprovalRequest
		}
		withApprovals, ok := client.(pendingApprovals)
		if !ok {
			continue
		}
		out = append(out, withApprovals.PendingApprovals()...)
	}
	return out
}

func (m *Manager) runtimeForSession(ctx context.Context, sessionID string) (runtime.Client, config.RuntimeID, error) {
	rid := m.resolveRuntimeID(sessionID, "")
	if rid == "" {
		return nil, "", fmt.Errorf("unknown runtime for session %q", sessionID)
	}
	return m.ensureRuntime(ctx, string(rid), "")
}

func (m *Manager) ensureRuntime(ctx context.Context, runtimeID string, startupCWD string) (runtime.Client, config.RuntimeID, error) {
	if strings.TrimSpace(runtimeID) == "" {
		return nil, "", fmt.Errorf("missing runtime")
	}
	rid := config.RuntimeID(runtimeID)

	m.mu.RLock()
	rt := m.runtimes[rid]
	m.mu.RUnlock()
	if rt == nil {
		return nil, "", fmt.Errorf("runtime %q not configured", rid)
	}

	rt.mu.Lock()
	defer rt.mu.Unlock()
	if rt.client != nil {
		if !runtimeClientAlive(rt.client) {
			log.Printf("[runtime] retiring stale %s runtime client", rid)
			_ = rt.client.Stop()
			rt.client = nil
		}
	}
	if rt.client != nil {
		return rt.client, rid, nil
	}

	settings, err := m.resolveSettings(rid, rt.settings, startupCWD)
	if err != nil {
		return nil, "", err
	}

	client := acp.NewClient(acp.Config{
		RuntimeID: string(rid),
		Command:   settings.Command,
		Args:      settings.Args,
		CWD:       settings.CWD,
		Env:       settings.Env,
	})
	if err := client.Start(ctx); err != nil {
		return nil, "", fmt.Errorf("start runtime %q: %w", rid, err)
	}
	rt.client = client
	go m.forwardEvents(client.Events())
	return client, rid, nil
}

func (m *Manager) resolveSettings(id config.RuntimeID, settings config.RuntimeSettings, startupCWD string) (config.RuntimeSettings, error) {
	if id == config.RuntimeClaudeCode {
		resolved, err := acpbin.Resolve(m.cfg, func(ev acpbin.ProgressEvent) {
			log.Printf("[runtime] %s: %d/%d bytes", ev.Phase, ev.BytesRead, ev.TotalBytes)
		})
		if err != nil {
			return config.RuntimeSettings{}, fmt.Errorf("resolve runtime %q: %w", id, err)
		}
		settings.Command = resolved
		settings, err = acpbin.InjectClaudeCodeExecutable(settings)
		if err != nil {
			return config.RuntimeSettings{}, fmt.Errorf("configure Claude Code executable wrapper: %w", err)
		}
		log.Printf("[runtime] resolved %s: %s", id, resolved)
	} else if id == config.RuntimeCodex {
		if config.IsRuntimeCommandOverridden(id) && settings.Command != "" {
			settings.CWD = selectRuntimeStartupCWD(settings.CWD, startupCWD)
			return settings, nil
		}
		resolved, err := codexbin.Resolve(m.cfg, func(ev codexbin.ProgressEvent) {
			log.Printf("[runtime] %s: %d/%d bytes", ev.Phase, ev.BytesRead, ev.TotalBytes)
		})
		if err != nil {
			return config.RuntimeSettings{}, fmt.Errorf("resolve runtime %q: %w", id, err)
		}
		settings.Command = resolved
		log.Printf("[runtime] resolved %s: %s", id, resolved)
	} else if id == config.RuntimeCopilot {
		settings = resolveCopilotSettings(settings)
	} else if id == config.RuntimeGemini {
		settings = resolveGeminiSettings(settings)
	} else if id == config.RuntimeGoose {
		settings = resolveGooseSettings(settings)
	} else if id == config.RuntimeOpenCode {
		settings = resolveOpenCodeSettings(settings)
	}

	if strings.TrimSpace(settings.Command) == "" {
		return config.RuntimeSettings{}, fmt.Errorf("runtime %q has no command configured", id)
	}
	settings.CWD = selectRuntimeStartupCWD(settings.CWD, startupCWD)
	return settings, nil
}

func selectRuntimeStartupCWD(configuredCWD string, startupCWD string) string {
	if strings.TrimSpace(configuredCWD) != "" {
		return configuredCWD
	}
	if strings.TrimSpace(startupCWD) != "" {
		return startupCWD
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	return home
}

func runtimeClientAlive(client runtime.Client) bool {
	withHealth, ok := client.(interface{ IsAlive() bool })
	if !ok {
		return true
	}
	return withHealth.IsAlive()
}

func shouldRetryRuntimeCall(client runtime.Client, err error) bool {
	if err == nil {
		return false
	}
	if !runtimeClientAlive(client) {
		return true
	}
	message := strings.ToLower(err.Error())
	return strings.Contains(message, "broken pipe") ||
		strings.Contains(message, "transport stopped") ||
		strings.Contains(message, "process exited")
}

func isSessionUnavailableForPrompt(err error) bool {
	if err == nil {
		return false
	}
	var rpcErr *acp.RPCError
	if errors.As(err, &rpcErr) {
		message := strings.ToLower(rpcErr.Message)
		return strings.Contains(message, "resource not found") ||
			strings.Contains(message, "session not found") ||
			strings.Contains(message, "unknown session")
	}
	message := strings.ToLower(err.Error())
	return strings.Contains(message, "resource not found") ||
		strings.Contains(message, "session not found") ||
		strings.Contains(message, "unknown session")
}

func (m *Manager) loadPromptSession(
	ctx context.Context,
	client runtime.Client,
	rid config.RuntimeID,
	sessionID string,
	snapshot sessionSnapshot,
	hasSnapshot bool,
) error {
	if !hasSnapshot || strings.TrimSpace(snapshot.CWD) == "" {
		return fmt.Errorf("session %q is not loaded and no cwd snapshot is available", sessionID)
	}
	permissionMode := currentConfigOptionValue(snapshot.ConfigOptions, "mode")
	model := currentConfigOptionValue(snapshot.ConfigOptions, "model")
	resp, err := client.LoadSession(ctx, sessionID, snapshot.CWD, permissionMode, model)
	if err != nil {
		return err
	}
	resp.ConfigOptions = m.enrichSessionConfigOptions(
		rid,
		sessionID,
		resp.ConfigOptions,
		permissionMode,
	)
	m.setSessionRuntime(sessionID, rid)
	m.persistSessionSnapshot(sessionID, rid, snapshot.CWD, resp.ConfigOptions)
	return nil
}

func (m *Manager) retireRuntimeClient(rid config.RuntimeID, target runtime.Client) {
	m.mu.RLock()
	rt := m.runtimes[rid]
	m.mu.RUnlock()
	if rt == nil {
		return
	}

	rt.mu.Lock()
	defer rt.mu.Unlock()
	if rt.client == nil || rt.client != target {
		return
	}
	_ = rt.client.Stop()
	rt.client = nil
}

func (m *Manager) forwardEvents(events <-chan appwire.Event) {
	for {
		select {
		case <-m.done:
			return
		case ev, ok := <-events:
			if !ok {
				return
			}
			m.captureSessionSnapshotFromEvent(ev)
			select {
			case <-m.done:
				return
			case m.events <- ev:
			}
		}
	}
}

func (m *Manager) resolveRuntimeID(sessionID string, runtimeID string) config.RuntimeID {
	if runtimeID != "" {
		return config.RuntimeID(runtimeID)
	}

	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.sessionRuntime[sessionID]
}

func (m *Manager) setSessionRuntime(sessionID string, runtimeID config.RuntimeID) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.sessionRuntime[sessionID] = runtimeID
}

func (m *Manager) applyStoredSessionSnapshots(
	sessions []domain.SessionSummary,
	rid config.RuntimeID,
) []domain.SessionSummary {
	for i := range sessions {
		sessions[i] = m.applyStoredSessionSnapshot(sessions[i], rid)
	}
	return sessions
}

func (m *Manager) applyStoredSessionSnapshot(
	session domain.SessionSummary,
	fallbackRuntime config.RuntimeID,
) domain.SessionSummary {
	runtimeID := config.RuntimeID(strings.TrimSpace(session.Runtime))
	if runtimeID == "" {
		runtimeID = fallbackRuntime
		if runtimeID != "" {
			session.Runtime = string(runtimeID)
		}
	}
	if session.SessionID == "" {
		return session
	}
	if runtimeID != "" {
		m.setSessionRuntime(session.SessionID, runtimeID)
	}
	storedSnapshot, hasStoredSnapshot := m.sessionSnapshot(
		runtimeID,
		session.SessionID,
	)
	if len(session.ConfigOptions) > 0 {
		if hasStoredSnapshot {
			session.ConfigOptions = mergeConfigOptionsByID(
				storedSnapshot.ConfigOptions,
				session.ConfigOptions,
			)
			if strings.TrimSpace(session.CWD) == "" && strings.TrimSpace(storedSnapshot.CWD) != "" {
				session.CWD = storedSnapshot.CWD
			}
			if strings.TrimSpace(session.Title) == "" && strings.TrimSpace(storedSnapshot.Title) != "" {
				session.Title = storedSnapshot.Title
			}
			if session.UpdatedAt.IsZero() && !storedSnapshot.UpdatedAt.IsZero() {
				session.UpdatedAt = storedSnapshot.UpdatedAt
			}
		}
		session.ConfigOptions = enrichModeConfigOptions(
			runtimeID,
			session.ConfigOptions,
			"",
		)
		return session
	}

	if !hasStoredSnapshot {
		if runtimeID != "" {
			m.persistSessionRuntime(session.SessionID, runtimeID)
		}
		return session
	}
	if len(storedSnapshot.ConfigOptions) > 0 {
		session.ConfigOptions = cloneConfigOptions(storedSnapshot.ConfigOptions)
		session.ConfigOptions = enrichModeConfigOptions(
			runtimeID,
			session.ConfigOptions,
			"",
		)
	}
	if strings.TrimSpace(session.CWD) == "" && strings.TrimSpace(storedSnapshot.CWD) != "" {
		session.CWD = storedSnapshot.CWD
	}
	if strings.TrimSpace(session.Title) == "" && strings.TrimSpace(storedSnapshot.Title) != "" {
		session.Title = storedSnapshot.Title
	}
	if session.UpdatedAt.IsZero() && !storedSnapshot.UpdatedAt.IsZero() {
		session.UpdatedAt = storedSnapshot.UpdatedAt
	}
	return session
}

func (m *Manager) enrichSessionConfigOptions(
	runtimeID config.RuntimeID,
	sessionID string,
	current []acpprotocol.SessionConfigOption,
	modeID string,
) []acpprotocol.SessionConfigOption {
	enriched := cloneConfigOptions(current)
	if sessionID != "" {
		if storedSnapshot, ok := m.sessionSnapshot(runtimeID, sessionID); ok {
			enriched = mergeConfigOptionsByID(storedSnapshot.ConfigOptions, enriched)
		}
	}
	return enrichModeConfigOptions(runtimeID, enriched, modeID)
}

func (m *Manager) sessionSnapshot(
	runtimeID config.RuntimeID,
	sessionID string,
) (sessionSnapshot, bool) {
	if m.snapshotStore == nil || runtimeID == "" || sessionID == "" {
		return sessionSnapshot{}, false
	}
	return m.snapshotStore.Get(string(runtimeID), sessionID)
}

func (m *Manager) snapshotSessionSummaries(
	runtimeID config.RuntimeID,
	sessionIDs []string,
) []domain.SessionSummary {
	if m.snapshotStore == nil || runtimeID == "" {
		return nil
	}

	targets := make(map[string]struct{}, len(sessionIDs))
	for _, sessionID := range sessionIDs {
		if sessionID == "" {
			continue
		}
		if resolvedRuntime := m.resolveRuntimeID(sessionID, ""); resolvedRuntime != "" &&
			resolvedRuntime != runtimeID {
			continue
		}
		targets[sessionID] = struct{}{}
	}

	runtimeSnapshots := m.snapshotStore.ListRuntime(string(runtimeID))
	if len(runtimeSnapshots) == 0 || len(targets) == 0 {
		return nil
	}

	summaries := make([]domain.SessionSummary, 0, len(runtimeSnapshots))
	for sessionID, snapshot := range runtimeSnapshots {
		if _, ok := targets[sessionID]; !ok {
			continue
		}
		summaries = append(summaries, m.sessionSummaryFromSnapshot(runtimeID, sessionID, snapshot))
	}

	sort.Slice(summaries, func(i, j int) bool {
		left := summaries[i].UpdatedAt
		right := summaries[j].UpdatedAt
		if !left.Equal(right) {
			return left.After(right)
		}
		return summaries[i].SessionID < summaries[j].SessionID
	})
	return summaries
}

func (m *Manager) snapshotRuntimeSessionSummaries(
	runtimeID config.RuntimeID,
) []domain.SessionSummary {
	if m.snapshotStore == nil || runtimeID == "" {
		return nil
	}
	runtimeSnapshots := m.snapshotStore.ListRuntime(string(runtimeID))
	if len(runtimeSnapshots) == 0 {
		return nil
	}
	summaries := make([]domain.SessionSummary, 0, len(runtimeSnapshots))
	for sessionID, snapshot := range runtimeSnapshots {
		if sessionID == "" {
			continue
		}
		summaries = append(summaries, m.sessionSummaryFromSnapshot(runtimeID, sessionID, snapshot))
	}
	sortSessionSummaries(summaries)
	return summaries
}

func (m *Manager) mergeListedSessionsWithSnapshots(
	sessions []domain.SessionSummary,
	rid config.RuntimeID,
) []domain.SessionSummary {
	resolved := m.applyStoredSessionSnapshots(sessions, rid)
	if m.snapshotStore == nil || rid == "" {
		sortSessionSummaries(resolved)
		return resolved
	}

	present := make(map[string]struct{}, len(resolved))
	for _, session := range resolved {
		if session.SessionID == "" {
			continue
		}
		present[session.SessionID] = struct{}{}
	}

	for sessionID, snapshot := range m.snapshotStore.ListRuntime(string(rid)) {
		if sessionID == "" {
			continue
		}
		if _, ok := present[sessionID]; ok {
			continue
		}
		resolved = append(resolved, m.sessionSummaryFromSnapshot(rid, sessionID, snapshot))
	}
	sortSessionSummaries(resolved)
	return resolved
}

func sortSessionSummaries(sessions []domain.SessionSummary) {
	sort.Slice(sessions, func(i, j int) bool {
		left := sessions[i].UpdatedAt
		right := sessions[j].UpdatedAt
		if !left.Equal(right) {
			return left.After(right)
		}
		return sessions[i].SessionID < sessions[j].SessionID
	})
}

func limitSessionSummaries(sessions []domain.SessionSummary, limit int) []domain.SessionSummary {
	if limit <= 0 || len(sessions) <= limit {
		return sessions
	}
	return sessions[:limit]
}

func (m *Manager) sessionSummaryFromSnapshot(
	runtimeID config.RuntimeID,
	sessionID string,
	snapshot sessionSnapshot,
) domain.SessionSummary {
	return m.applyStoredSessionSnapshot(domain.SessionSummary{
		SessionID:     sessionID,
		CWD:           snapshot.CWD,
		Title:         snapshot.Title,
		Runtime:       string(runtimeID),
		UpdatedAt:     snapshot.UpdatedAt,
		ConfigOptions: cloneConfigOptions(snapshot.ConfigOptions),
	}, runtimeID)
}

func (m *Manager) persistSessionRuntime(
	sessionID string,
	runtimeID config.RuntimeID,
) {
	if sessionID == "" || runtimeID == "" || m.snapshotStore == nil {
		return
	}
	if err := m.snapshotStore.Ensure(string(runtimeID), sessionID); err != nil {
		log.Printf("[runtime] save session snapshot runtime failed: %v", err)
	}
}

func (m *Manager) persistSessionSnapshot(
	sessionID string,
	runtimeID config.RuntimeID,
	cwd string,
	configOptions []acpprotocol.SessionConfigOption,
	updatedAt ...time.Time,
) {
	if sessionID == "" || runtimeID == "" || m.snapshotStore == nil {
		return
	}
	var snapshotUpdatedAt time.Time
	if len(updatedAt) > 0 {
		snapshotUpdatedAt = updatedAt[0].UTC()
	}
	if err := m.snapshotStore.Put(string(runtimeID), sessionID, sessionSnapshot{
		ConfigOptions: configOptions,
		CWD:           cwd,
		UpdatedAt:     snapshotUpdatedAt,
	}); err != nil {
		log.Printf("[runtime] save session snapshot failed: %v", err)
	}
}

func (m *Manager) updateSessionSnapshot(
	sessionID string,
	update func(*sessionSnapshot) bool,
) {
	if sessionID == "" || m.snapshotStore == nil {
		return
	}
	runtimeID := m.resolveRuntimeID(sessionID, "")
	if runtimeID == "" {
		return
	}
	if err := m.snapshotStore.Update(string(runtimeID), sessionID, update); err != nil {
		log.Printf("[runtime] update session snapshot failed: %v", err)
	}
}

func (m *Manager) mergeResolvedSessionsWithSnapshots(
	sessions []domain.SessionSummary,
	rid config.RuntimeID,
	sessionIDs []string,
) []domain.SessionSummary {
	targets := make(map[string]struct{}, len(sessionIDs))
	for _, sessionID := range sessionIDs {
		if sessionID == "" {
			continue
		}
		targets[sessionID] = struct{}{}
	}

	filtered := make([]domain.SessionSummary, 0, len(sessions))
	for _, s := range sessions {
		if _, ok := targets[s.SessionID]; ok {
			filtered = append(filtered, s)
		}
	}
	resolved := m.applyStoredSessionSnapshots(filtered, rid)

	if m.snapshotStore == nil || rid == "" {
		return resolved
	}

	present := make(map[string]struct{}, len(resolved))
	for _, session := range resolved {
		if session.SessionID == "" {
			continue
		}
		present[session.SessionID] = struct{}{}
	}

	supplemental := make([]domain.SessionSummary, 0, len(targets))
	for _, sessionID := range compactSessionIDs(sessionIDs) {
		if _, ok := present[sessionID]; ok {
			continue
		}
		snapshot, ok := m.snapshotStore.Get(string(rid), sessionID)
		if !ok {
			continue
		}
		supplemental = append(supplemental, m.sessionSummaryFromSnapshot(rid, sessionID, snapshot))
	}
	if len(supplemental) == 0 {
		return resolved
	}

	sort.Slice(supplemental, func(i, j int) bool {
		left := supplemental[i].UpdatedAt
		right := supplemental[j].UpdatedAt
		if !left.Equal(right) {
			return left.After(right)
		}
		return supplemental[i].SessionID < supplemental[j].SessionID
	})
	return append(resolved, supplemental...)
}

func compactSessionIDs(sessionIDs []string) []string {
	seen := make(map[string]struct{}, len(sessionIDs))
	out := make([]string, 0, len(sessionIDs))
	for _, sessionID := range sessionIDs {
		sessionID = strings.TrimSpace(sessionID)
		if sessionID == "" {
			continue
		}
		if _, ok := seen[sessionID]; ok {
			continue
		}
		seen[sessionID] = struct{}{}
		out = append(out, sessionID)
	}
	return out
}

func (m *Manager) captureSessionSnapshotFromEvent(ev appwire.Event) {
	if ev.SessionID == "" {
		return
	}
	switch ev.Type {
	case appwire.EventModeChanged:
		if ev.ModeChanged == nil {
			return
		}
		if update := ev.ModeChanged.ACPConfigOption; update != nil &&
			len(update.ConfigOptions) > 0 {
			m.updateSessionSnapshot(ev.SessionID, func(snapshot *sessionSnapshot) bool {
				snapshot.ConfigOptions = mergeConfigOptionsByID(
					snapshot.ConfigOptions,
					update.ConfigOptions,
				)
				return true
			})
			return
		}
		currentModeID := strings.TrimSpace(ev.ModeChanged.App.CurrentModeID)
		if currentModeID == "" {
			return
		}
		m.updateSessionSnapshot(ev.SessionID, func(snapshot *sessionSnapshot) bool {
			next, changed := updateModeConfigCurrentValue(
				snapshot.ConfigOptions,
				currentModeID,
			)
			if !changed {
				return false
			}
			snapshot.ConfigOptions = next
			return true
		})
	case appwire.EventModelChanged:
		if ev.ConfigChanged == nil {
			return
		}
		if update := ev.ConfigChanged.ACP; update != nil &&
			len(update.ConfigOptions) > 0 {
			m.updateSessionSnapshot(ev.SessionID, func(snapshot *sessionSnapshot) bool {
				snapshot.ConfigOptions = mergeConfigOptionsByID(
					snapshot.ConfigOptions,
					update.ConfigOptions,
				)
				return true
			})
			return
		}
		configID := strings.TrimSpace(ev.ConfigChanged.App.ConfigID)
		if configID == "" {
			return
		}
		m.updateSessionSnapshot(ev.SessionID, func(snapshot *sessionSnapshot) bool {
			next, changed := updateConfigOptionCurrentValue(
				snapshot.ConfigOptions,
				configID,
				ev.ConfigChanged.App.CurrentValue,
			)
			if !changed {
				return false
			}
			snapshot.ConfigOptions = next
			return true
		})
	}
}

func mergeConfigOptionsByID(
	current []acpprotocol.SessionConfigOption,
	incoming []acpprotocol.SessionConfigOption,
) []acpprotocol.SessionConfigOption {
	if len(incoming) == 0 {
		return cloneConfigOptions(current)
	}
	if len(current) == 0 {
		return cloneConfigOptions(incoming)
	}
	merged := cloneConfigOptions(current)
	for _, next := range incoming {
		replaced := false
		for i, existing := range merged {
			if existing.ID == next.ID {
				merged[i] = mergeConfigOption(existing, next)
				replaced = true
				break
			}
		}
		if !replaced {
			merged = append(merged, next)
		}
	}
	return merged
}

func mergeConfigOption(
	existing acpprotocol.SessionConfigOption,
	incoming acpprotocol.SessionConfigOption,
) acpprotocol.SessionConfigOption {
	merged := existing
	if incoming.Meta != nil {
		merged.Meta = incoming.Meta
	}
	if strings.TrimSpace(incoming.ID) != "" {
		merged.ID = incoming.ID
	}
	if strings.TrimSpace(incoming.Name) != "" {
		merged.Name = incoming.Name
	}
	if strings.TrimSpace(incoming.Type) != "" {
		merged.Type = incoming.Type
	}
	if incoming.Description != nil {
		merged.Description = incoming.Description
	}
	if incoming.Category != nil {
		merged.Category = incoming.Category
	}
	if strings.TrimSpace(incoming.CurrentValue) != "" {
		merged.CurrentValue = incoming.CurrentValue
	}
	if len(incoming.Options.Flatten()) > 0 {
		merged.Options = incoming.Options
	}
	return merged
}

func enrichModeConfigOptions(
	runtimeID config.RuntimeID,
	current []acpprotocol.SessionConfigOption,
	modeID string,
) []acpprotocol.SessionConfigOption {
	modeOption, ok := runtimeModeConfigOption(runtimeID)
	if !ok {
		return cloneConfigOptions(current)
	}
	resolvedModeID := strings.TrimSpace(modeID)
	if resolvedModeID == "" {
		resolvedModeID = currentConfigOptionValue(current, "mode")
	}
	if resolvedModeID == "" {
		return cloneConfigOptions(current)
	}
	modeOption.CurrentValue = resolvedModeID
	return mergeConfigOptionsByID(
		[]acpprotocol.SessionConfigOption{modeOption},
		current,
	)
}

func runtimeModeConfigOption(
	runtimeID config.RuntimeID,
) (acpprotocol.SessionConfigOption, bool) {
	for _, option := range runtimeConfigOptions(runtimeID) {
		category := strings.TrimSpace(derefString(option.Category))
		if category == "mode" || option.ID == "mode" {
			return option, true
		}
	}
	return acpprotocol.SessionConfigOption{}, false
}

func currentConfigOptionValue(
	options []acpprotocol.SessionConfigOption,
	configID string,
) string {
	target := strings.TrimSpace(configID)
	if target == "" {
		return ""
	}
	for _, option := range options {
		category := strings.TrimSpace(derefString(option.Category))
		if option.ID == target || category == target {
			return strings.TrimSpace(option.CurrentValue)
		}
	}
	return ""
}

func updateConfigOptionCurrentValue(
	current []acpprotocol.SessionConfigOption,
	configID string,
	value string,
) ([]acpprotocol.SessionConfigOption, bool) {
	if len(current) == 0 || strings.TrimSpace(configID) == "" {
		return cloneConfigOptions(current), false
	}
	next := cloneConfigOptions(current)
	for i := range next {
		if next[i].ID != configID {
			continue
		}
		if next[i].CurrentValue == value {
			return next, false
		}
		next[i].CurrentValue = value
		return next, true
	}
	return next, false
}

func updateModeConfigCurrentValue(
	current []acpprotocol.SessionConfigOption,
	modeID string,
) ([]acpprotocol.SessionConfigOption, bool) {
	if strings.TrimSpace(modeID) == "" {
		return cloneConfigOptions(current), false
	}
	next := cloneConfigOptions(current)
	for i := range next {
		category := strings.TrimSpace(derefString(next[i].Category))
		if category != "mode" && next[i].ID != "mode" {
			continue
		}
		if next[i].CurrentValue == modeID {
			return next, false
		}
		next[i].CurrentValue = modeID
		return next, true
	}
	modeCategory := "mode"
	next = append(next, acpprotocol.SessionConfigOption{
		ID:           "mode",
		Name:         "Mode",
		Type:         "select",
		Category:     &modeCategory,
		CurrentValue: modeID,
	})
	return next, true
}

func derefString(value *string) string {
	if value == nil {
		return ""
	}
	return *value
}

func (m *Manager) startedClients() []runtime.Client {
	m.mu.RLock()
	runtimes := make([]*managedRuntime, 0, len(m.runtimes))
	for _, rt := range m.runtimes {
		runtimes = append(runtimes, rt)
	}
	m.mu.RUnlock()

	clients := make([]runtime.Client, 0, len(runtimes))
	for _, rt := range runtimes {
		rt.mu.Lock()
		client := rt.client
		rt.mu.Unlock()
		if client != nil {
			clients = append(clients, client)
		}
	}
	return clients
}

func (m *Manager) configuredRuntimeIDs() []config.RuntimeID {
	m.mu.RLock()
	ids := make([]config.RuntimeID, 0, len(m.runtimes))
	for id := range m.runtimes {
		ids = append(ids, id)
	}
	m.mu.RUnlock()

	sort.Slice(ids, func(i, j int) bool {
		return runtimeLabel(ids[i]) < runtimeLabel(ids[j])
	})
	return ids
}

func runtimeLabel(id config.RuntimeID) string {
	switch id {
	case config.RuntimeCopilot:
		return "GitHub Copilot"
	case config.RuntimeClaudeCode:
		return "Claude Code"
	case config.RuntimeCodex:
		return "Codex"
	case config.RuntimeGemini:
		return "Gemini CLI"
	case config.RuntimeGoose:
		return "Goose"
	case config.RuntimeOpenCode:
		return "OpenCode"
	default:
		return string(id)
	}
}

func runtimeConfigOptions(id config.RuntimeID) []acpprotocol.SessionConfigOption {
	switch id {
	case config.RuntimeClaudeCode:
		return []acpprotocol.SessionConfigOption{
			{
				ID:           "mode",
				Name:         "Approval Preset",
				Type:         "select",
				Category:     stringPtr("mode"),
				CurrentValue: "bypassPermissions",
				Options: acpprotocol.SessionConfigSelectOptions{
					Ungrouped: []acpprotocol.SessionConfigSelectOption{
						{
							Value:       "default",
							Name:        "Default",
							Description: stringPtr("Standard behavior, prompts for dangerous operations"),
						},
						{
							Value:       "acceptEdits",
							Name:        "Accept Edits",
							Description: stringPtr("Auto-accept file edit operations"),
						},
						{
							Value:       "plan",
							Name:        "Plan",
							Description: stringPtr("Planning mode, no actual tool execution"),
						},
						{
							Value:       "dontAsk",
							Name:        "Don't Ask",
							Description: stringPtr("Don't prompt for permissions, deny if not pre-approved"),
						},
						{
							Value:       "bypassPermissions",
							Name:        "Skip Perms",
							Description: stringPtr("Bypass all permission checks"),
						},
					},
				},
			},
		}
	case config.RuntimeCodex:
		return []acpprotocol.SessionConfigOption{
			{
				ID:           "mode",
				Name:         "Approval Preset",
				Type:         "select",
				Category:     stringPtr("mode"),
				CurrentValue: "read-only",
				Options: acpprotocol.SessionConfigSelectOptions{
					Ungrouped: []acpprotocol.SessionConfigSelectOption{
						{
							Value:       "read-only",
							Name:        "Read Only",
							Description: stringPtr("Codex can read files in the current workspace. Approval is required to edit files or access the internet."),
						},
						{
							Value:       "auto",
							Name:        "Default",
							Description: stringPtr("Codex can read and edit files in the current workspace, and run commands. Approval is required to access the internet or edit other files."),
						},
						{
							Value:       "full-access",
							Name:        "Full Access",
							Description: stringPtr("Codex can edit files outside this workspace and access the internet without asking for approval."),
						},
					},
				},
			},
		}
	case config.RuntimeCopilot:
		return []acpprotocol.SessionConfigOption{
			{
				ID:           "mode",
				Name:         "Mode",
				Type:         "select",
				Category:     stringPtr("mode"),
				CurrentValue: copilotModeAgent,
				Options: acpprotocol.SessionConfigSelectOptions{
					Ungrouped: []acpprotocol.SessionConfigSelectOption{
						{
							Value:       copilotModeAgent,
							Name:        "Agent",
							Description: stringPtr("Default conversational agent mode."),
						},
						{
							Value:       copilotModePlan,
							Name:        "Plan",
							Description: stringPtr("Planning mode for multi-step tasks."),
						},
						{
							Value:       copilotModeAutopilot,
							Name:        "Autopilot",
							Description: stringPtr("Experimental autonomous mode that runs to completion."),
						},
					},
				},
			},
		}
	case config.RuntimeGemini:
		return []acpprotocol.SessionConfigOption{
			{
				ID:           "mode",
				Name:         "Mode",
				Type:         "select",
				Category:     stringPtr("mode"),
				CurrentValue: geminiModeDefault,
				Options: acpprotocol.SessionConfigSelectOptions{
					Ungrouped: []acpprotocol.SessionConfigSelectOption{
						{
							Value:       geminiModeDefault,
							Name:        "Default",
							Description: stringPtr("Standard Gemini approval mode."),
						},
						{
							Value:       geminiModeAutoEdit,
							Name:        "Auto Edit",
							Description: stringPtr("Auto-approves edit operations in the workspace."),
						},
						{
							Value:       geminiModeYolo,
							Name:        "YOLO",
							Description: stringPtr("Most permissive Gemini approval mode."),
						},
						{
							Value:       geminiModePlan,
							Name:        "Plan",
							Description: stringPtr("Plan-first mode with minimal execution."),
						},
					},
				},
			},
		}
	case config.RuntimeGoose:
		return []acpprotocol.SessionConfigOption{
			{
				ID:           "mode",
				Name:         "Mode",
				Type:         "select",
				Category:     stringPtr("mode"),
				CurrentValue: gooseModeAuto,
				Options: acpprotocol.SessionConfigSelectOptions{
					Ungrouped: []acpprotocol.SessionConfigSelectOption{
						{
							Value:       gooseModeAuto,
							Name:        "Auto",
							Description: stringPtr("Automatically approve tool calls."),
						},
						{
							Value:       gooseModeSmartApprove,
							Name:        "Smart Approve",
							Description: stringPtr("Ask only for sensitive tool calls."),
						},
						{
							Value:       gooseModeApprove,
							Name:        "Approve",
							Description: stringPtr("Ask before every tool call."),
						},
						{
							Value:       gooseModeChat,
							Name:        "Chat",
							Description: stringPtr("Chat only, no tool calls."),
						},
					},
				},
			},
		}
	case config.RuntimeOpenCode:
		return []acpprotocol.SessionConfigOption{
			{
				ID:           "mode",
				Name:         "Mode",
				Type:         "select",
				Category:     stringPtr("mode"),
				CurrentValue: "build",
				Options: acpprotocol.SessionConfigSelectOptions{
					Ungrouped: []acpprotocol.SessionConfigSelectOption{
						{
							Value:       "build",
							Name:        "Build",
							Description: stringPtr("Default OpenCode agent mode with full tool execution."),
						},
						{
							Value:       "plan",
							Name:        "Plan",
							Description: stringPtr("Planning mode that disallows edit tools."),
						},
					},
				},
			},
		}
	default:
		return nil
	}
}

func runtimeReady(id config.RuntimeID, settings config.RuntimeSettings) bool {
	switch id {
	case config.RuntimeCopilot:
		return copilotRuntimeReady(settings)
	case config.RuntimeGemini:
		return geminiRuntimeReady(settings)
	case config.RuntimeGoose:
		return gooseRuntimeReady(settings)
	case config.RuntimeOpenCode:
		return openCodeRuntimeReady(settings)
	default:
		return true
	}
}

func copilotRuntimeReady(settings config.RuntimeSettings) bool {
	settings = resolveCopilotSettings(settings)
	command := strings.TrimSpace(settings.Command)
	if command == "" {
		return false
	}
	_, err := exec.LookPath(command)
	return err == nil
}

func geminiRuntimeReady(settings config.RuntimeSettings) bool {
	settings = resolveGeminiSettings(settings)
	command := strings.TrimSpace(settings.Command)
	if command == "" {
		return false
	}
	_, err := exec.LookPath(command)
	return err == nil
}

func gooseRuntimeReady(settings config.RuntimeSettings) bool {
	settings = resolveGooseSettings(settings)
	command := strings.TrimSpace(settings.Command)
	if command == "" {
		return false
	}
	_, err := exec.LookPath(command)
	return err == nil
}

func openCodeRuntimeReady(settings config.RuntimeSettings) bool {
	settings = resolveOpenCodeSettings(settings)
	command := strings.TrimSpace(settings.Command)
	if command == "" {
		return false
	}
	_, err := exec.LookPath(command)
	return err == nil
}

func supportsManagedRuntime(id config.RuntimeID) bool {
	switch id {
	case config.RuntimeClaudeCode, config.RuntimeCodex, config.RuntimeCopilot, config.RuntimeGemini, config.RuntimeGoose, config.RuntimeOpenCode:
		return true
	default:
		return false
	}
}

func resolveCopilotSettings(settings config.RuntimeSettings) config.RuntimeSettings {
	if strings.TrimSpace(settings.Command) == "" {
		settings.Command = "copilot"
		settings.Args = defaultCopilotArgs(settings.Args)
		return settings
	}
	if len(settings.Args) == 0 && looksLikeCopilotBinary(settings.Command) {
		settings.Args = defaultCopilotArgs(nil)
	}
	return settings
}

func resolveGeminiSettings(settings config.RuntimeSettings) config.RuntimeSettings {
	if strings.TrimSpace(settings.Command) == "" {
		settings.Command = "gemini"
		settings.Args = defaultGeminiArgs(settings.Args)
		return settings
	}
	if len(settings.Args) == 0 && looksLikeGeminiBinary(settings.Command) {
		settings.Args = defaultGeminiArgs(nil)
	}
	return settings
}

func resolveGooseSettings(settings config.RuntimeSettings) config.RuntimeSettings {
	if strings.TrimSpace(settings.Command) == "" {
		settings.Command = "goose"
		settings.Args = defaultGooseArgs(settings.Args)
		return settings
	}
	if len(settings.Args) == 0 && looksLikeGooseBinary(settings.Command) {
		settings.Args = defaultGooseArgs(nil)
	}
	return settings
}

func defaultCopilotArgs(args []string) []string {
	if len(args) > 0 {
		return args
	}
	return []string{"--acp", "--stdio"}
}

func looksLikeCopilotBinary(command string) bool {
	base := filepath.Base(strings.TrimSpace(command))
	return base == "copilot" || base == "copilot.exe"
}

func defaultGeminiArgs(args []string) []string {
	if len(args) > 0 {
		return args
	}
	return []string{"--acp"}
}

func defaultGooseArgs(args []string) []string {
	if len(args) > 0 {
		return args
	}
	return []string{"acp"}
}

func looksLikeGeminiBinary(command string) bool {
	base := filepath.Base(strings.TrimSpace(command))
	return base == "gemini" || base == "gemini.exe"
}

func looksLikeGooseBinary(command string) bool {
	base := filepath.Base(strings.TrimSpace(command))
	return base == "goose" || base == "goose.exe"
}

func resolveOpenCodeSettings(settings config.RuntimeSettings) config.RuntimeSettings {
	if strings.TrimSpace(settings.Command) == "" {
		settings.Command = "opencode"
		settings.Args = defaultOpenCodeArgs(settings.Args)
		return settings
	}
	if len(settings.Args) == 0 && looksLikeOpenCodeBinary(settings.Command) {
		settings.Args = []string{"acp"}
	}
	return settings
}

func defaultOpenCodeArgs(args []string) []string {
	if len(args) > 0 {
		return args
	}
	return []string{"acp"}
}

func looksLikeOpenCodeBinary(command string) bool {
	base := filepath.Base(strings.TrimSpace(command))
	return base == "opencode" || base == "opencode.exe"
}

func stringPtr(value string) *string {
	return &value
}
