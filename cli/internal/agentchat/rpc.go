package agentchat

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io/fs"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/LaLanMo/muxagent/cli/internal/acpprotocol"
	"github.com/LaLanMo/muxagent/cli/internal/appwire"
	"github.com/LaLanMo/muxagent/cli/internal/appwireconv"
	"github.com/LaLanMo/muxagent/cli/internal/domain"
	runtimemanager "github.com/LaLanMo/muxagent/cli/internal/runtime/manager"
	"github.com/LaLanMo/muxagent/cli/internal/sessionattach"
	"github.com/LaLanMo/muxagent/cli/internal/worktree"
)

const (
	defaultResyncPageBytes  = 256 * 1024
	defaultResyncPageEvents = 128
	maxResyncPageBytes      = 512 * 1024
	maxResyncPageEvents     = 256
)

// Runtime is the runtime/manager subset needed by Agent Chat.
type Runtime interface {
	RuntimeList() []runtimemanager.RuntimeInfo
	NewSession(ctx context.Context, runtimeID, cwd, permissionMode string) (string, string, acpprotocol.NewSessionResponse, error)
	LoadSession(ctx context.Context, runtimeID, sessionID, cwd, permissionMode, model string) (string, acpprotocol.LoadSessionResponse, error)
	ResolveSessions(ctx context.Context, runtimeID string, sessionIDs []string) ([]domain.SessionSummary, error)
	Prompt(ctx context.Context, sessionID string, content []domain.ContentBlock) (string, *domain.PromptUsage, error)
	Cancel(ctx context.Context, sessionID string) error
	SetMode(ctx context.Context, sessionID, modeID string) error
	SetConfigOption(ctx context.Context, sessionID, configID, value string) error
	ReplyPermission(ctx context.Context, sessionID, requestID, optionID string) error
	PendingApprovals() []domain.ApprovalRequest
}

type sessionListRuntime interface {
	ListSessions(ctx context.Context, runtimeID string, limit int) ([]domain.SessionSummary, error)
}

type scopedLoadRuntime interface {
	LoadSessionScoped(ctx context.Context, runtimeID, sessionID, cwd, permissionMode, model string) (string, acpprotocol.LoadSessionResponse, []appwire.Event, error)
}

func (s *Service) HandleRPC(ctx context.Context, payload appwire.RPCRequest) (any, string) {
	switch payload.Method {
	case "runtime.list":
		return s.RuntimeList(ctx)
	case "session.create":
		params, err := appwire.DecodeCreateSessionParams(payload.Params)
		if err != nil {
			return nil, "invalid create params: " + err.Error()
		}
		return s.CreateSession(ctx, params)
	case "session.load":
		params, err := appwire.DecodeLoadSessionParams(payload.Params)
		if err != nil {
			return nil, "invalid load params: " + err.Error()
		}
		return s.LoadSession(ctx, params)
	case "session.attach":
		params, err := appwire.DecodeAttachSessionParams(payload.Params)
		if err != nil {
			return nil, "invalid attach params: " + err.Error()
		}
		return s.AttachSession(ctx, params)
	case "session.resolve":
		params, err := appwire.DecodeResolveSessionsParams(payload.Params)
		if err != nil {
			return nil, "invalid resolve params: " + err.Error()
		}
		return s.ResolveSessions(ctx, params)
	case "session.list", "session.recent":
		params, err := appwire.DecodeListSessionsParams(payload.Params)
		if err != nil {
			return nil, "invalid list params: " + err.Error()
		}
		return s.ListSessions(ctx, params)
	case "session.prompt":
		params, err := appwire.DecodePromptParams(payload.Params)
		if err != nil {
			return nil, "invalid prompt params: " + err.Error()
		}
		return s.Prompt(ctx, params)
	case "session.cancel":
		params, err := appwire.DecodeCancelParams(payload.Params)
		if err != nil {
			return nil, "invalid cancel params: " + err.Error()
		}
		return s.Cancel(ctx, params)
	case "session.setMode":
		params, err := appwire.DecodeSetModeParams(payload.Params)
		if err != nil {
			return nil, "invalid setMode params: " + err.Error()
		}
		return s.SetMode(ctx, params)
	case "session.setConfigOption":
		params, err := appwire.DecodeSetConfigOptionParams(payload.Params)
		if err != nil {
			return nil, "invalid setConfigOption params: " + err.Error()
		}
		return s.SetConfigOption(ctx, params)
	case "approval.reply":
		params, err := appwire.DecodeReplyPermissionParams(payload.Params)
		if err != nil {
			return nil, "invalid replyPermission params: " + err.Error()
		}
		return s.ReplyPermission(ctx, params)
	case "events.resync":
		params, err := appwire.DecodeResyncEventsParams(payload.Params)
		if err != nil {
			return nil, "invalid resync params: " + err.Error()
		}
		return s.ResyncEvents(ctx, params)
	case "events.resyncPage":
		params, err := appwire.DecodeResyncEventsPageParams(payload.Params)
		if err != nil {
			return nil, "invalid resync page params: " + err.Error()
		}
		return s.ResyncEventsPage(ctx, params)
	case "events.head":
		return s.ReplayHead(ctx)
	case "approvals.pending":
		return s.PendingApprovals(ctx)
	case "fs.list":
		params, err := appwire.DecodeFsListParams(payload.Params)
		if err != nil {
			return nil, "invalid fs.list params: " + err.Error()
		}
		return s.FsList(ctx, params)
	case "fs.search":
		params, err := appwire.DecodeFsSearchParams(payload.Params)
		if err != nil {
			return nil, "invalid fs.search params: " + err.Error()
		}
		return s.FsSearch(ctx, params)
	case "session.git_status":
		params, err := appwire.DecodeSessionGitStatusParams(payload.Params)
		if err != nil {
			return nil, "invalid session.git_status params: " + err.Error()
		}
		return s.SessionGitStatus(ctx, params)
	default:
		return nil, fmt.Sprintf("unknown method: %s", payload.Method)
	}
}

func (s *Service) RuntimeList(_ context.Context) (any, string) {
	if s == nil || s.runtime == nil {
		return nil, "runtime not available"
	}
	runtimes := s.runtime.RuntimeList()
	items := make([]appwire.RuntimeInfo, 0, len(runtimes))
	for _, runtime := range runtimes {
		items = append(items, appwire.RuntimeInfo{
			ID:            runtime.ID,
			Label:         runtime.Label,
			Ready:         runtime.Ready,
			ConfigOptions: runtime.ConfigOptions,
		})
	}
	return appwire.RuntimeListResult{Runtimes: items}, ""
}

func (s *Service) CreateSession(ctx context.Context, params appwire.CreateSessionParams) (any, string) {
	if s == nil || s.runtime == nil {
		return nil, "runtime not available"
	}
	cwd := params.CWD
	if cwd == "" {
		return nil, "missing cwd"
	}
	if strings.HasPrefix(cwd, "~/") || cwd == "~" {
		if home, err := os.UserHomeDir(); err == nil {
			cwd = filepath.Join(home, cwd[1:])
		}
	}
	permissionMode := params.PermissionMode
	requestedRuntime := s.resolveRequestedRuntime(params.Runtime)
	if requestedRuntime == "" {
		return nil, "missing runtime"
	}
	useWorktree := params.UseWorktree

	actualCWD := cwd
	var wtMapping *worktree.Mapping

	if useWorktree {
		repoRoot, err := worktree.FindRepoRoot(cwd)
		if err != nil {
			return nil, "worktree requires a git repository"
		}
		wtID, err := randomHex(8)
		if err != nil {
			return nil, fmt.Sprintf("failed to generate worktree id: %v", err)
		}
		wtPath, err := worktree.Create(repoRoot, wtID)
		if err != nil {
			return nil, fmt.Sprintf("failed to create worktree: %v", err)
		}
		relPath, err := worktree.NormalizeRepoRelativePath(repoRoot, cwd)
		if err != nil {
			return nil, fmt.Sprintf("failed to compute relative path: %v", err)
		}
		actualCWD, err = worktree.WorktreeCWDPath(wtPath, relPath)
		if err != nil {
			cleanupErr := worktree.Cleanup(repoRoot, wtPath, worktree.BranchName(wtID))
			if cleanupErr != nil {
				return nil, fmt.Sprintf("failed to resolve worktree path: %v (cleanup: %v)", err, cleanupErr)
			}
			return nil, fmt.Sprintf("failed to resolve worktree path: %v", err)
		}
		wtMapping = &worktree.Mapping{
			WorktreeID:   wtID,
			WorktreePath: wtPath,
			RepoRoot:     repoRoot,
			BranchName:   worktree.BranchName(wtID),
			RelativeCWD:  relPath,
		}
	}

	sessionID, actualRuntime, acpResp, err := s.runtime.NewSession(ctx, requestedRuntime, actualCWD, permissionMode)
	if err != nil {
		return nil, err.Error()
	}
	if acpResp.SessionID == "" {
		acpResp.SessionID = sessionID
	}
	if acpResp.SessionID != sessionID {
		return nil, fmt.Sprintf("runtime returned mismatched session id: app=%s acp=%s", sessionID, acpResp.SessionID)
	}
	createdAt := time.Now().UTC()
	s.SetSessionStatus(sessionID, domain.SessionStatusIdle)
	s.SetSessionCWD(sessionID, actualCWD)

	if wtMapping != nil && s.wtStore != nil {
		s.wtStore.Set(sessionID, *wtMapping)
		if err := s.wtStore.Save(); err != nil {
			log.Printf("worktree store save: %v", err)
		}
	}

	resp := appwire.SessionCreateResult{
		App: appwire.SessionCreateResultApp{
			SessionID: sessionID,
			Runtime:   actualRuntime,
			CWD:       actualCWD,
			Title:     "New chat",
			Status:    appwire.SessionStatusIdle,
			UpdatedAt: createdAt,
		},
		ACP: acpResp,
	}
	if len(acpResp.ConfigOptions) > 0 {
		log.Printf("[relay] session.create response includes %d configOptions", len(acpResp.ConfigOptions))
	} else {
		log.Printf("[relay] session.create response has NO configOptions")
	}
	return resp, ""
}

func (s *Service) LoadSession(ctx context.Context, params appwire.LoadSessionParams) (any, string) {
	if s == nil || s.runtime == nil {
		return nil, "runtime not available"
	}
	sessionID := params.SessionID
	if sessionID == "" {
		return nil, "missing sessionId"
	}
	cwd := params.CWD
	if cwd == "" {
		return nil, "missing cwd"
	}

	if s.wtStore != nil {
		if wt := s.wtStore.Get(sessionID); wt != nil {
			resolvedCWD, err := worktree.ResolveMappedCWD(wt)
			if err != nil {
				return nil, err.Error()
			}
			cwd = resolvedCWD
		}
	}

	permissionMode := params.PermissionMode
	model := params.Model
	requestedRuntime := s.resolveRequestedRuntime(params.Runtime)
	if requestedRuntime == "" {
		return nil, "missing runtime"
	}
	return s.withSessionMutation(sessionID, func() (any, string) {
		if sink := scopedEventSinkFromContext(ctx); sink != nil {
			if scoped, ok := s.runtime.(scopedLoadRuntime); ok {
				actualRuntime, acpResp, events, err := scoped.LoadSessionScoped(ctx, requestedRuntime, sessionID, cwd, permissionMode, model)
				if err != nil {
					return nil, err.Error()
				}
				s.EnsureSessionStatus(sessionID, domain.SessionStatusIdle)
				s.SetSessionCWD(sessionID, cwd)
				s.deliverScopedEvents(sink, events)
				return appwire.SessionLoadResult{
					App: appwire.SessionLoadResultApp{
						OK:      true,
						Runtime: actualRuntime,
						CWD:     cwd,
					},
					ACP: acpResp,
				}, ""
			}
		}

		actualRuntime, acpResp, err := s.runtime.LoadSession(ctx, requestedRuntime, sessionID, cwd, permissionMode, model)
		if err != nil {
			return nil, err.Error()
		}
		s.EnsureSessionStatus(sessionID, domain.SessionStatusIdle)
		s.SetSessionCWD(sessionID, cwd)
		resp := appwire.SessionLoadResult{
			App: appwire.SessionLoadResultApp{
				OK:      true,
				Runtime: actualRuntime,
				CWD:     cwd,
			},
			ACP: acpResp,
		}
		return resp, ""
	})
}

func (s *Service) deliverScopedEvents(sink ScopedEventSink, events []appwire.Event) {
	if sink == nil {
		return
	}
	for _, event := range events {
		s.applyEventStatus(event)
		sink(NormalizeEventForTransport(event))
	}
}

func (s *Service) AttachSession(ctx context.Context, params appwire.AttachSessionParams) (any, string) {
	result, err := sessionattach.Execute(
		ctx,
		s.attachRegistry,
		s,
		sessionattach.Request{
			SessionID: params.SessionID,
			Runtime:   s.resolveRequestedRuntime(params.Runtime),
		},
	)
	if err != nil {
		return nil, err.Error()
	}

	s.EnsureSessionStatus(result.SessionID, result.Status)
	s.SetSessionCWD(result.SessionID, result.CWD)

	return appwire.SessionAttachResult{
		OK:        true,
		SessionID: result.SessionID,
		Runtime:   result.Runtime,
		CWD:       result.CWD,
		Title:     result.Title,
		Status:    sessionStatusToWire(result.Status),
		CreatedAt: result.CreatedAt,
		UpdatedAt: result.UpdatedAt,
	}, ""
}

func (s *Service) ResolveSessions(ctx context.Context, params appwire.ResolveSessionsParams) (any, string) {
	if s == nil || s.runtime == nil {
		return nil, "runtime not available"
	}
	wanted := make(map[string]struct{}, len(params.SessionIDs))
	for _, id := range params.SessionIDs {
		if id != "" {
			wanted[id] = struct{}{}
		}
	}
	runtimeID := params.Runtime
	targetIDs := make([]string, 0, len(wanted))
	for id := range wanted {
		targetIDs = append(targetIDs, id)
	}
	all, err := s.runtime.ResolveSessions(ctx, runtimeID, targetIDs)
	if err != nil {
		return nil, err.Error()
	}
	present := make(map[string]struct{}, len(all))
	for _, session := range all {
		present[session.SessionID] = struct{}{}
	}
	if len(wanted) > 0 {
		for id := range wanted {
			if _, ok := present[id]; !ok {
				s.ClearSessionStatus(id)
			}
		}
	}
	return appwire.SessionResolveResult{Sessions: s.wireResolvedSessions(all)}, ""
}

func (s *Service) ListSessions(ctx context.Context, params appwire.ListSessionsParams) (any, string) {
	if s == nil || s.runtime == nil {
		return nil, "runtime not available"
	}
	lister, ok := s.runtime.(sessionListRuntime)
	if !ok {
		return nil, "session list not available"
	}
	limit := params.Limit
	if limit < 0 {
		limit = 0
	}
	if limit > 200 {
		limit = 200
	}
	sessions, err := lister.ListSessions(ctx, params.Runtime, limit)
	if err != nil {
		return nil, err.Error()
	}
	return appwire.SessionResolveResult{Sessions: s.wireResolvedSessions(sessions)}, ""
}

func (s *Service) wireResolvedSessions(sessions []domain.SessionSummary) []appwire.ResolvedSession {
	resolved := make([]appwire.ResolvedSession, 0, len(sessions))
	for _, session := range sessions {
		resolved = append(resolved, appwire.ResolvedSession{
			SessionID:     session.SessionID,
			CWD:           session.CWD,
			Title:         session.Title,
			Runtime:       session.Runtime,
			UpdatedAt:     session.UpdatedAt,
			Status:        sessionStatusToWire(s.ResolvedSessionStatus(session.SessionID)),
			ConfigOptions: session.ConfigOptions,
		})
	}
	return resolved
}

func (s *Service) resolveRequestedRuntime(runtimeID string) string {
	runtimeID = strings.TrimSpace(runtimeID)
	if runtimeID != "" || s == nil || s.runtime == nil {
		return runtimeID
	}

	runtimes := s.runtime.RuntimeList()
	for _, runtimeInfo := range runtimes {
		id := strings.TrimSpace(runtimeInfo.ID)
		if id == "claude-code" {
			return id
		}
	}

	return ""
}

func (s *Service) ResolveRequestedRuntime(runtimeID string) string {
	return s.resolveRequestedRuntime(runtimeID)
}

func (s *Service) Prompt(_ context.Context, params appwire.PromptParams) (any, string) {
	if s == nil || s.runtime == nil {
		return nil, "runtime not available"
	}
	sessionID := params.SessionID
	if sessionID == "" {
		return nil, "missing sessionId"
	}
	content := appwireconv.ContentBlocksFromWire(params.Content)
	if len(content) == 0 && params.Text != "" {
		content = []domain.ContentBlock{{Type: "text", Text: params.Text}}
	}

	s.SetSessionStatus(sessionID, domain.SessionStatusRunning)

	if !s.startBackground(func(ctx context.Context) {
		stopReason, usage, err := s.runtime.Prompt(ctx, sessionID, content)
		now := time.Now()
		if err != nil {
			if evErr := s.SendEvent(appwire.Event{
				Type:      appwire.EventRunFailed,
				SessionID: sessionID,
				At:        now,
				RunFailed: &appwire.RunFailedEvent{
					App: appwire.RunFailedEventApp{
						Error: appwire.SessionError{
							Code:    "prompt_error",
							Message: err.Error(),
						},
					},
				},
			}); evErr != nil && !s.shouldIgnoreTransportError(evErr) {
				log.Printf("send run.failed event: %v", evErr)
			}
			return
		}
		runFinished := appwire.RunFinishedEventApp{StopReason: stopReason}
		if usage != nil {
			runFinished.TotalTokens = usage.TotalTokens
			runFinished.InputTokens = usage.InputTokens
			runFinished.OutputTokens = usage.OutputTokens
			runFinished.CachedReadTokens = usage.CachedReadTokens
			runFinished.CachedWriteTokens = usage.CachedWriteTokens
		}
		if evErr := s.SendEvent(appwire.Event{
			Type:      appwire.EventRunFinished,
			SessionID: sessionID,
			At:        now,
			RunFinished: &appwire.RunFinishedEvent{
				App: runFinished,
			},
		}); evErr != nil && !s.shouldIgnoreTransportError(evErr) {
			log.Printf("send run.finished event: %v", evErr)
		}
	}) {
		return nil, "agentchat closed"
	}

	return appwire.AcceptedResult{Accepted: true}, ""
}

func (s *Service) Cancel(ctx context.Context, params appwire.CancelParams) (any, string) {
	if s == nil || s.runtime == nil {
		return nil, "runtime not available"
	}
	if params.SessionID == "" {
		return nil, "missing sessionId"
	}
	return s.withSessionMutation(params.SessionID, func() (any, string) {
		if err := s.runtime.Cancel(ctx, params.SessionID); err != nil {
			return nil, err.Error()
		}
		return appwire.OKResult{OK: true}, ""
	})
}

func (s *Service) SetMode(ctx context.Context, params appwire.SetModeParams) (any, string) {
	if s == nil || s.runtime == nil {
		return nil, "runtime not available"
	}
	if params.SessionID == "" {
		return nil, "missing sessionId"
	}
	if params.PermissionMode == "" {
		return nil, "missing permissionMode"
	}
	return s.withSessionMutation(params.SessionID, func() (any, string) {
		if err := s.runtime.SetMode(ctx, params.SessionID, params.PermissionMode); err != nil {
			return nil, err.Error()
		}
		return appwire.OKResult{OK: true}, ""
	})
}

func (s *Service) SetConfigOption(ctx context.Context, params appwire.SetConfigOptionParams) (any, string) {
	if s == nil || s.runtime == nil {
		return nil, "runtime not available"
	}
	if params.SessionID == "" {
		return nil, "missing sessionId"
	}
	if params.ConfigID == "" {
		return nil, "missing configId"
	}
	if params.Value == "" {
		return nil, "missing value"
	}
	return s.withSessionMutation(params.SessionID, func() (any, string) {
		if err := s.runtime.SetConfigOption(ctx, params.SessionID, params.ConfigID, params.Value); err != nil {
			return nil, err.Error()
		}
		return appwire.OKResult{OK: true}, ""
	})
}

func (s *Service) ReplyPermission(ctx context.Context, params appwire.ReplyPermissionParams) (any, string) {
	if s == nil || s.runtime == nil {
		return nil, "runtime not available"
	}
	if params.SessionID == "" {
		return nil, "missing sessionId"
	}
	if params.RequestID == "" {
		return nil, "missing requestId"
	}
	if params.OptionID == "" {
		return nil, "missing optionId"
	}
	return s.withSessionMutation(params.SessionID, func() (any, string) {
		if err := s.runtime.ReplyPermission(ctx, params.SessionID, params.RequestID, params.OptionID); err != nil {
			return nil, err.Error()
		}
		if err := s.SendEvent(appwire.Event{
			Type:      appwire.EventApprovalReplied,
			SessionID: params.SessionID,
			At:        time.Now(),
			Approval: &appwire.ApprovalRequest{
				App: appwire.ApprovalApp{RequestID: params.RequestID},
			},
		}); err != nil && !s.shouldIgnoreTransportError(err) {
			log.Printf("send approval.replied event: %v", err)
		}
		return appwire.OKResult{OK: true}, ""
	})
}

func (s *Service) PendingApprovals(_ context.Context) (any, string) {
	if s == nil || s.runtime == nil {
		return nil, "runtime not available"
	}
	approvals := s.runtime.PendingApprovals()
	return appwire.PendingApprovalsResult{
		Approvals: appwireconv.ApprovalRequestsFromDomain(approvals),
	}, ""
}

func (s *Service) ResyncEvents(_ context.Context, params appwire.ResyncEventsParams) (any, string) {
	if s == nil || s.eventBuf == nil {
		return nil, "event buffer not available"
	}
	snapshot := s.eventBuf.ReplaySince(params.StreamEpoch, params.LastSeq)
	return appwire.ResyncEventsResult{
		Events:             snapshot.Events,
		Status:             snapshot.Status,
		StreamEpoch:        snapshot.StreamEpoch,
		ReplayedThroughSeq: snapshot.ReplayedThroughSeq,
	}, ""
}

func (s *Service) ResyncEventsPage(_ context.Context, params appwire.ResyncEventsPageParams) (any, string) {
	if s == nil || s.eventBuf == nil {
		return nil, "event buffer not available"
	}

	page := s.eventBuf.ReplaySincePage(
		params.StreamEpoch,
		params.LastSeq,
		clampResyncPageBytes(params.MaxBytes),
		clampResyncPageEvents(params.MaxEvents),
	)
	return appwire.ResyncEventsPageResult{
		Events:             page.Events,
		Status:             page.Status,
		StreamEpoch:        page.StreamEpoch,
		ReplayedThroughSeq: page.ReplayedThroughSeq,
		HasMore:            page.HasMore,
		NextAfterSeq:       page.NextAfterSeq,
	}, ""
}

func (s *Service) ReplayHead(_ context.Context) (any, string) {
	if s == nil || s.eventBuf == nil {
		return nil, "event buffer not available"
	}
	return appwire.ReplayHeadResult{
		StreamEpoch:        s.eventBuf.StreamEpoch(),
		ReplayedThroughSeq: s.eventBuf.Seq(),
	}, ""
}

func clampResyncPageBytes(requested int) int {
	if requested <= 0 {
		return defaultResyncPageBytes
	}
	if requested > maxResyncPageBytes {
		return maxResyncPageBytes
	}
	return requested
}

func clampResyncPageEvents(requested int) int {
	if requested <= 0 {
		return defaultResyncPageEvents
	}
	if requested > maxResyncPageEvents {
		return maxResyncPageEvents
	}
	return requested
}

func (s *Service) FsList(_ context.Context, params appwire.FsListParams) (any, string) {
	if params.SessionID == "" {
		return nil, "missing sessionId"
	}
	cwd, ok := s.SessionCWD(params.SessionID)
	if !ok || cwd == "" {
		return nil, "unknown session"
	}

	relPath := params.Path
	target, err := safePath(cwd, relPath)
	if err != nil {
		return nil, err.Error()
	}

	dirEntries, err := os.ReadDir(target)
	if err != nil {
		return nil, err.Error()
	}

	sort.Slice(dirEntries, func(i, j int) bool {
		di, dj := dirEntries[i].IsDir(), dirEntries[j].IsDir()
		if di != dj {
			return di
		}
		return dirEntries[i].Name() < dirEntries[j].Name()
	})

	const maxEntries = 200
	entries := make([]appwire.FsEntry, 0, min(len(dirEntries), maxEntries))
	if relPath == "." {
		relPath = ""
	}
	for _, entry := range dirEntries {
		if len(entries) >= maxEntries {
			break
		}
		entryPath := entry.Name()
		if relPath != "" {
			entryPath = filepath.Join(relPath, entry.Name())
		}
		entries = append(entries, appwire.FsEntry{
			Name:  entry.Name(),
			Path:  entryPath,
			IsDir: entry.IsDir(),
		})
	}
	return appwire.FsListResult{Entries: entries}, ""
}

func (s *Service) FsSearch(ctx context.Context, params appwire.FsSearchParams) (any, string) {
	if params.SessionID == "" {
		return nil, "missing sessionId"
	}
	if params.Query == "" {
		return nil, "missing query"
	}
	cwd, ok := s.SessionCWD(params.SessionID)
	if !ok || cwd == "" {
		return nil, "unknown session"
	}

	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	const maxResults = 50
	lowerQuery := strings.ToLower(params.Query)
	var results []appwire.FsSearchEntry

	_ = filepath.WalkDir(cwd, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if ctx.Err() != nil {
			return ctx.Err()
		}
		if d.IsDir() && d.Name() == ".git" {
			return filepath.SkipDir
		}
		if path == cwd {
			return nil
		}
		if strings.Contains(strings.ToLower(d.Name()), lowerQuery) {
			rel, _ := filepath.Rel(cwd, path)
			results = append(results, appwire.FsSearchEntry{
				Path:  rel,
				IsDir: d.IsDir(),
			})
		}
		return nil
	})

	sort.Slice(results, func(i, j int) bool {
		di, dj := results[i].IsDir, results[j].IsDir
		if di != dj {
			return di
		}
		return len(results[i].Path) < len(results[j].Path)
	})

	if len(results) > maxResults {
		results = results[:maxResults]
	}
	return appwire.FsSearchResult{Results: results}, ""
}

func safePath(cwd, relPath string) (string, error) {
	if relPath == "" || relPath == "." {
		return filepath.EvalSymlinks(cwd)
	}
	target := filepath.Clean(filepath.Join(cwd, relPath))
	if !strings.HasPrefix(target, cwd+string(filepath.Separator)) && target != cwd {
		return "", fmt.Errorf("path outside project")
	}
	realTarget, err := filepath.EvalSymlinks(target)
	if err != nil {
		return "", err
	}
	realCWD, err := filepath.EvalSymlinks(cwd)
	if err != nil {
		return "", err
	}
	if !strings.HasPrefix(realTarget, realCWD+string(filepath.Separator)) && realTarget != realCWD {
		return "", fmt.Errorf("symlink escape detected")
	}
	return realTarget, nil
}

func sessionStatusToWire(status domain.SessionStatus) appwire.SessionStatus {
	return appwire.SessionStatus(status)
}

func randomHex(n int) (string, error) {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return "", fmt.Errorf("random bytes: %w", err)
	}
	return hex.EncodeToString(b)[:n], nil
}

func (s *Service) shouldIgnoreTransportError(err error) bool {
	if err == nil {
		return true
	}
	return s != nil && s.ignoreTransportError != nil && s.ignoreTransportError(err)
}
