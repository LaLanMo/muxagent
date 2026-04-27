package agentchat

import (
	"context"
	"encoding/json"
	"strings"
	"testing"
	"time"

	"github.com/LaLanMo/muxagent/cli/internal/acpprotocol"
	"github.com/LaLanMo/muxagent/cli/internal/appwire"
	"github.com/LaLanMo/muxagent/cli/internal/domain"
	runtimemanager "github.com/LaLanMo/muxagent/cli/internal/runtime/manager"
)

func TestHandleRPCReplayMethodsUseEventBufferContract(t *testing.T) {
	buf := NewEventBuffer(8)
	first := buf.Push(appwire.Event{Type: appwire.EventMessageDelta, SessionID: "sid"})
	second := buf.Push(appwire.Event{Type: appwire.EventReasoning, SessionID: "sid"})
	svc := New(Config{EventBuffer: buf})

	result, errStr := svc.HandleRPC(context.Background(), rpcRequest(t, "events.resync", appwire.ResyncEventsParams{
		StreamEpoch: buf.StreamEpoch(),
		LastSeq:     first.Seq,
	}))
	if errStr != "" {
		t.Fatalf("events.resync error = %q", errStr)
	}
	resync, ok := result.(appwire.ResyncEventsResult)
	if !ok {
		t.Fatalf("events.resync result type = %T, want appwire.ResyncEventsResult", result)
	}
	if resync.Status != appwire.ResyncStatusOK {
		t.Fatalf("events.resync status = %q, want %q", resync.Status, appwire.ResyncStatusOK)
	}
	if resync.StreamEpoch != buf.StreamEpoch() {
		t.Fatalf("events.resync streamEpoch = %d, want %d", resync.StreamEpoch, buf.StreamEpoch())
	}
	if resync.ReplayedThroughSeq != second.Seq {
		t.Fatalf("events.resync replayedThroughSeq = %d, want %d", resync.ReplayedThroughSeq, second.Seq)
	}
	if len(resync.Events) != 1 || resync.Events[0].Seq != second.Seq {
		t.Fatalf("events.resync events = %#v, want one event seq=%d", resync.Events, second.Seq)
	}

	headResult, errStr := svc.HandleRPC(context.Background(), rpcRequest(t, "events.head", nil))
	if errStr != "" {
		t.Fatalf("events.head error = %q", errStr)
	}
	head, ok := headResult.(appwire.ReplayHeadResult)
	if !ok {
		t.Fatalf("events.head result type = %T, want appwire.ReplayHeadResult", headResult)
	}
	if head.StreamEpoch != buf.StreamEpoch() || head.ReplayedThroughSeq != second.Seq {
		t.Fatalf("events.head = %#v, want streamEpoch=%d seq=%d", head, buf.StreamEpoch(), second.Seq)
	}
}

func TestHandleRPCResyncPageClampsAndContinues(t *testing.T) {
	buf := NewEventBuffer(8)
	first := buf.Push(appwire.Event{Type: appwire.EventMessageDelta, SessionID: "sid"})
	second := buf.Push(appwire.Event{Type: appwire.EventReasoning, SessionID: "sid"})
	svc := New(Config{EventBuffer: buf})

	result, errStr := svc.HandleRPC(context.Background(), rpcRequest(t, "events.resyncPage", appwire.ResyncEventsPageParams{
		StreamEpoch: buf.StreamEpoch(),
		LastSeq:     0,
		MaxEvents:   1,
	}))
	if errStr != "" {
		t.Fatalf("events.resyncPage error = %q", errStr)
	}
	page, ok := result.(appwire.ResyncEventsPageResult)
	if !ok {
		t.Fatalf("events.resyncPage result type = %T, want appwire.ResyncEventsPageResult", result)
	}
	if page.Status != appwire.ResyncStatusOK {
		t.Fatalf("events.resyncPage status = %q, want %q", page.Status, appwire.ResyncStatusOK)
	}
	if len(page.Events) != 1 || page.Events[0].Seq != first.Seq {
		t.Fatalf("events.resyncPage events = %#v, want one event seq=%d", page.Events, first.Seq)
	}
	if !page.HasMore {
		t.Fatal("events.resyncPage hasMore = false, want true")
	}
	if page.NextAfterSeq != first.Seq {
		t.Fatalf("events.resyncPage nextAfterSeq = %d, want %d", page.NextAfterSeq, first.Seq)
	}
	if page.ReplayedThroughSeq != second.Seq {
		t.Fatalf("events.resyncPage replayedThroughSeq = %d, want %d", page.ReplayedThroughSeq, second.Seq)
	}
}

func rpcRequest(t *testing.T, method string, params any) appwire.RPCRequest {
	t.Helper()
	var raw json.RawMessage
	if params != nil {
		data, err := json.Marshal(params)
		if err != nil {
			t.Fatalf("marshal %s params: %v", method, err)
		}
		raw = data
	}
	return appwire.RPCRequest{Method: method, Params: raw}
}

func TestCreateSessionReturnsAppOwnedMetadata(t *testing.T) {
	rt := &createMetadataRuntime{}
	svc := New(Config{Runtime: rt})

	result, errStr := svc.CreateSession(context.Background(), appwire.CreateSessionParams{
		CWD:            "/tmp/workspace",
		Runtime:        "codex",
		PermissionMode: "read-only",
	})
	if errStr != "" {
		t.Fatalf("CreateSession error = %q", errStr)
	}
	create, ok := result.(appwire.SessionCreateResult)
	if !ok {
		t.Fatalf("CreateSession result type = %T, want appwire.SessionCreateResult", result)
	}
	if create.App.SessionID != "sid" || create.App.Runtime != "codex" || create.App.CWD != "/tmp/workspace" {
		t.Fatalf("CreateSession app metadata = %#v", create.App)
	}
	if create.App.Title != "New chat" {
		t.Fatalf("CreateSession app title = %q, want New chat", create.App.Title)
	}
	if create.App.Status != appwire.SessionStatusIdle {
		t.Fatalf("CreateSession app status = %q, want idle", create.App.Status)
	}
	if create.App.UpdatedAt.IsZero() {
		t.Fatal("CreateSession app updatedAt is zero")
	}
	if got := svc.ResolvedSessionStatus("sid"); got != domain.SessionStatusIdle {
		t.Fatalf("service status = %q, want idle", got)
	}
}

func TestCreateSessionRejectsMismatchedACPSessionID(t *testing.T) {
	rt := &createMetadataRuntime{
		sessionID:    "sid-app",
		acpSessionID: "sid-acp",
	}
	svc := New(Config{Runtime: rt})

	result, errStr := svc.CreateSession(context.Background(), appwire.CreateSessionParams{
		CWD:     "/tmp/workspace",
		Runtime: "codex",
	})
	if result != nil {
		t.Fatalf("CreateSession result = %#v, want nil", result)
	}
	if !strings.Contains(errStr, "mismatched session id") {
		t.Fatalf("CreateSession error = %q, want mismatched session id", errStr)
	}
	if got := svc.ResolvedSessionStatus("sid-app"); got != domain.SessionStatusIdle {
		t.Fatalf("service status for rejected session = %q, want unchanged idle default", got)
	}
}

func TestPromptBackgroundWorkUsesServiceCloseContext(t *testing.T) {
	rt := &blockingPromptRuntime{
		started: make(chan struct{}),
		done:    make(chan struct{}),
	}
	svc := New(Config{
		Runtime:     rt,
		EventBuffer: NewEventBuffer(8),
		Transport:   noopTransport{},
	})

	result, errStr := svc.Prompt(context.Background(), appwire.PromptParams{
		SessionID: "sid",
		Text:      "hello",
	})
	if errStr != "" {
		t.Fatalf("Prompt error = %q", errStr)
	}
	if accepted, ok := result.(appwire.AcceptedResult); !ok || !accepted.Accepted {
		t.Fatalf("Prompt result = %#v, want accepted", result)
	}

	select {
	case <-rt.started:
	case <-time.After(time.Second):
		t.Fatal("timed out waiting for runtime prompt")
	}

	closeCtx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	if err := svc.Close(closeCtx); err != nil {
		t.Fatalf("Close: %v", err)
	}

	select {
	case <-rt.done:
	default:
		t.Fatal("runtime prompt did not observe service close context")
	}
}

func TestHandleRPCSessionListUsesRuntimeSummaries(t *testing.T) {
	updated := time.Now().UTC()
	rt := &listingAgentRuntime{
		sessions: []domain.SessionSummary{{
			SessionID: "sid",
			CWD:       "/tmp/project",
			Title:     "Recent chat",
			Runtime:   "codex",
			UpdatedAt: updated,
		}},
	}
	svc := New(Config{Runtime: rt})
	svc.SetSessionStatus("sid", domain.SessionStatusRunning)

	result, errStr := svc.HandleRPC(context.Background(), rpcRequest(t, "session.list", appwire.ListSessionsParams{
		Runtime: "codex",
		Limit:   500,
	}))
	if errStr != "" {
		t.Fatalf("session.list error = %q", errStr)
	}
	if rt.runtimeID != "codex" {
		t.Fatalf("runtimeID = %q, want codex", rt.runtimeID)
	}
	if rt.limit != 200 {
		t.Fatalf("limit = %d, want clamp to 200", rt.limit)
	}
	list, ok := result.(appwire.SessionResolveResult)
	if !ok {
		t.Fatalf("session.list result type = %T, want appwire.SessionResolveResult", result)
	}
	if len(list.Sessions) != 1 {
		t.Fatalf("sessions = %#v, want one", list.Sessions)
	}
	got := list.Sessions[0]
	if got.SessionID != "sid" || got.Status != appwire.SessionStatusRunning || !got.UpdatedAt.Equal(updated) {
		t.Fatalf("session = %#v, want sid running updated=%s", got, updated)
	}
}

func TestLoadSessionWithScopedSinkDoesNotUseGlobalReplay(t *testing.T) {
	buf := NewEventBuffer(8)
	transport := &recordingTransport{}
	rt := &scopedLoadFakeRuntime{
		events: []appwire.Event{
			{Type: appwire.EventMessageDelta, SessionID: "sid"},
			{Type: appwire.EventHistoryComplete, SessionID: "sid"},
		},
	}
	svc := New(Config{
		Runtime:     rt,
		EventBuffer: buf,
		Transport:   transport,
	})

	var scoped []appwire.Event
	ctx := WithScopedEventSink(context.Background(), func(event appwire.Event) {
		scoped = append(scoped, event)
	})
	result, errStr := svc.LoadSession(ctx, appwire.LoadSessionParams{
		SessionID: "sid",
		CWD:       "/tmp/project",
		Runtime:   "codex",
	})
	if errStr != "" {
		t.Fatalf("LoadSession error = %q", errStr)
	}
	if _, ok := result.(appwire.SessionLoadResult); !ok {
		t.Fatalf("LoadSession result type = %T, want appwire.SessionLoadResult", result)
	}
	if !rt.scopedCalled {
		t.Fatal("scoped runtime load was not used")
	}
	if len(scoped) != 2 {
		t.Fatalf("scoped events = %#v, want 2", scoped)
	}
	if scoped[0].Seq != 0 || scoped[1].Seq != 0 {
		t.Fatalf("scoped events got global seqs: %#v", scoped)
	}
	if got := buf.Seq(); got != 0 {
		t.Fatalf("event buffer seq = %d, want 0", got)
	}
	if len(transport.events) != 0 {
		t.Fatalf("transport events = %#v, want none", transport.events)
	}
}

type noopTransport struct{}

func (noopTransport) DeliverEvent(appwire.Event) error {
	return nil
}

func (noopTransport) DeliverLiveEvent(appwire.Event) error {
	return nil
}

type blockingPromptRuntime struct {
	started chan struct{}
	done    chan struct{}
}

func (r *blockingPromptRuntime) RuntimeList() []runtimemanager.RuntimeInfo {
	return nil
}

func (r *blockingPromptRuntime) NewSession(context.Context, string, string, string) (string, string, acpprotocol.NewSessionResponse, error) {
	return "", "", acpprotocol.NewSessionResponse{}, nil
}

func (r *blockingPromptRuntime) LoadSession(context.Context, string, string, string, string, string) (string, acpprotocol.LoadSessionResponse, error) {
	return "", acpprotocol.LoadSessionResponse{}, nil
}

func (r *blockingPromptRuntime) ResolveSessions(context.Context, string, []string) ([]domain.SessionSummary, error) {
	return nil, nil
}

func (r *blockingPromptRuntime) Prompt(ctx context.Context, _ string, _ []domain.ContentBlock) (string, *domain.PromptUsage, error) {
	close(r.started)
	<-ctx.Done()
	close(r.done)
	return "", nil, ctx.Err()
}

func (r *blockingPromptRuntime) Cancel(context.Context, string) error {
	return nil
}

func (r *blockingPromptRuntime) SetMode(context.Context, string, string) error {
	return nil
}

func (r *blockingPromptRuntime) SetConfigOption(context.Context, string, string, string) error {
	return nil
}

func (r *blockingPromptRuntime) ReplyPermission(context.Context, string, string, string) error {
	return nil
}

func (r *blockingPromptRuntime) PendingApprovals() []domain.ApprovalRequest {
	return nil
}

type createMetadataRuntime struct {
	blockingPromptRuntime
	sessionID    string
	acpSessionID string
}

func (r *createMetadataRuntime) NewSession(context.Context, string, string, string) (string, string, acpprotocol.NewSessionResponse, error) {
	sessionID := r.sessionID
	if sessionID == "" {
		sessionID = "sid"
	}
	acpSessionID := r.acpSessionID
	if acpSessionID == "" {
		acpSessionID = sessionID
	}
	return sessionID, "codex", acpprotocol.NewSessionResponse{SessionID: acpSessionID}, nil
}

type scopedLoadFakeRuntime struct {
	blockingPromptRuntime
	events       []appwire.Event
	scopedCalled bool
}

func (r *scopedLoadFakeRuntime) LoadSessionScoped(context.Context, string, string, string, string, string) (string, acpprotocol.LoadSessionResponse, []appwire.Event, error) {
	r.scopedCalled = true
	return "codex", acpprotocol.LoadSessionResponse{}, r.events, nil
}

type listingAgentRuntime struct {
	blockingPromptRuntime
	sessions  []domain.SessionSummary
	runtimeID string
	limit     int
}

func (r *listingAgentRuntime) ListSessions(_ context.Context, runtimeID string, limit int) ([]domain.SessionSummary, error) {
	r.runtimeID = runtimeID
	r.limit = limit
	return r.sessions, nil
}
