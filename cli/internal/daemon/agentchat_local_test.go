package daemon

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/LaLanMo/muxagent/cli/internal/acpprotocol"
	"github.com/LaLanMo/muxagent/cli/internal/agentchat"
	"github.com/LaLanMo/muxagent/cli/internal/appwire"
	"github.com/LaLanMo/muxagent/cli/internal/control"
	"github.com/LaLanMo/muxagent/cli/internal/domain"
	"github.com/LaLanMo/muxagent/cli/internal/relayws"
	runtimemanager "github.com/LaLanMo/muxagent/cli/internal/runtime/manager"
)

type fakeEventTransport struct {
	err error
}

func (f fakeEventTransport) DeliverEvent(appwire.Event) error {
	return f.err
}

func (f fakeEventTransport) DeliverLiveEvent(appwire.Event) error {
	return f.err
}

func TestHandleAgentChatRPCUsesDaemonOwnedService(t *testing.T) {
	buf := agentchat.NewEventBuffer(8)
	buf.Push(appwire.Event{Type: appwire.EventMessageDelta, SessionID: "sid-1"})
	d := &Daemon{chat: agentchat.New(agentchat.Config{EventBuffer: buf})}

	body, err := json.Marshal(control.AgentChatRPCRequest{Method: "events.head"})
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}
	req := httptest.NewRequest(http.MethodPost, "/agentchat/rpc", bytes.NewReader(body))
	rec := httptest.NewRecorder()
	d.handleAgentChatRPC(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d: %s", rec.Code, http.StatusOK, rec.Body.String())
	}
	var resp control.AgentChatRPCResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("Unmarshal response: %v", err)
	}
	if resp.Error != "" {
		t.Fatalf("error = %q, want empty", resp.Error)
	}
	var head appwire.ReplayHeadResult
	if err := json.Unmarshal(resp.Result, &head); err != nil {
		t.Fatalf("Unmarshal result: %v", err)
	}
	if head.StreamEpoch != buf.StreamEpoch() || head.ReplayedThroughSeq != buf.Seq() {
		t.Fatalf("head = %+v, want streamEpoch=%d seq=%d", head, buf.StreamEpoch(), buf.Seq())
	}
}

func TestHandleAgentChatRPCReturnsScopedLoadEvents(t *testing.T) {
	buf := agentchat.NewEventBuffer(8)
	d := &Daemon{chat: agentchat.New(agentchat.Config{
		EventBuffer: buf,
		Runtime: &scopedLoadRuntime{
			events: []appwire.Event{{
				Type:      appwire.EventHistoryComplete,
				SessionID: "sid-scoped",
			}},
		},
	})}

	body, err := json.Marshal(control.AgentChatRPCRequest{
		Method: "session.load",
		Params: json.RawMessage(`{
			"sessionId": "sid-scoped",
			"cwd": "/tmp/project",
			"runtime": "codex"
		}`),
	})
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}
	req := httptest.NewRequest(http.MethodPost, "/agentchat/rpc", bytes.NewReader(body))
	rec := httptest.NewRecorder()
	d.handleAgentChatRPC(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d: %s", rec.Code, http.StatusOK, rec.Body.String())
	}
	var resp control.AgentChatRPCResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("Unmarshal response: %v", err)
	}
	if resp.Error != "" {
		t.Fatalf("error = %q, want empty", resp.Error)
	}
	if len(resp.Events) != 1 || resp.Events[0].Type != appwire.EventHistoryComplete {
		t.Fatalf("events = %#v, want scoped history.complete", resp.Events)
	}
	if got := buf.Seq(); got != 0 {
		t.Fatalf("buffer seq = %d, want 0", got)
	}
}

func TestLocalEventBrokerSubscribeReplaysWithoutDuplicate(t *testing.T) {
	buf := agentchat.NewEventBuffer(8)
	broker := newLocalEventBroker(buf)
	first := buf.Push(appwire.Event{Type: appwire.EventMessageDelta, SessionID: "sid-1"})

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	initial, live := broker.subscribe(ctx, buf.StreamEpoch(), 0)
	if len(initial) != 1 || initial[0].Seq != first.Seq {
		t.Fatalf("initial = %+v, want seq %d", initial, first.Seq)
	}

	broker.publishBuffered(first)
	select {
	case duplicate := <-live:
		t.Fatalf("got duplicate event %+v", duplicate)
	case <-time.After(50 * time.Millisecond):
	}

	second := buf.Push(appwire.Event{Type: appwire.EventReasoning, SessionID: "sid-1"})
	broker.publishBuffered(second)
	select {
	case got := <-live:
		if got.Seq != second.Seq {
			t.Fatalf("live seq = %d, want %d", got.Seq, second.Seq)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for live event")
	}
}

type scopedLoadRuntime struct {
	events []appwire.Event
}

func (r *scopedLoadRuntime) RuntimeList() []runtimemanager.RuntimeInfo {
	return nil
}

func (r *scopedLoadRuntime) NewSession(context.Context, string, string, string) (string, string, acpprotocol.NewSessionResponse, error) {
	return "", "", acpprotocol.NewSessionResponse{}, nil
}

func (r *scopedLoadRuntime) LoadSession(context.Context, string, string, string, string, string) (string, acpprotocol.LoadSessionResponse, error) {
	return "codex", acpprotocol.LoadSessionResponse{}, nil
}

func (r *scopedLoadRuntime) LoadSessionScoped(context.Context, string, string, string, string, string) (string, acpprotocol.LoadSessionResponse, []appwire.Event, error) {
	return "codex", acpprotocol.LoadSessionResponse{}, r.events, nil
}

func (r *scopedLoadRuntime) ResolveSessions(context.Context, string, []string) ([]domain.SessionSummary, error) {
	return nil, nil
}

func (r *scopedLoadRuntime) Prompt(context.Context, string, []domain.ContentBlock) (string, *domain.PromptUsage, error) {
	return "", nil, nil
}

func (r *scopedLoadRuntime) Cancel(context.Context, string) error {
	return nil
}

func (r *scopedLoadRuntime) SetMode(context.Context, string, string) error {
	return nil
}

func (r *scopedLoadRuntime) SetConfigOption(context.Context, string, string, string) error {
	return nil
}

func (r *scopedLoadRuntime) ReplyPermission(context.Context, string, string, string) error {
	return nil
}

func (r *scopedLoadRuntime) PendingApprovals() []domain.ApprovalRequest {
	return nil
}

func TestHandleAgentChatEventsFlushesHeadersBeforeEvents(t *testing.T) {
	d := &Daemon{localEvents: newLocalEventBroker(agentchat.NewEventBuffer(8))}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	req := httptest.NewRequest(http.MethodGet, "/agentchat/events", nil).WithContext(ctx)
	rec := httptest.NewRecorder()
	done := make(chan struct{})

	go func() {
		defer close(done)
		d.handleAgentChatEvents(rec, req)
	}()

	deadline := time.After(2 * time.Second)
	for !rec.Flushed {
		select {
		case <-deadline:
			t.Fatal("timed out waiting for event stream headers to flush")
		default:
			time.Sleep(10 * time.Millisecond)
		}
	}
	cancel()
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("event stream handler did not stop after context cancel")
	}
}

func TestLocalAgentChatTransportDoesNotGateLiveEventsOnExpectedRelayDrop(t *testing.T) {
	transport := &localAgentChatTransport{
		relay: fakeEventTransport{err: relayws.ErrNoActiveSession},
		local: newLocalEventBroker(agentchat.NewEventBuffer(8)),
	}
	svc := agentchat.New(agentchat.Config{
		Transport: transport,
	})

	err := svc.SendLiveEvent(appwire.Event{
		Type:      appwire.EventApprovalRequested,
		SessionID: "sid-1",
	})
	if err != nil {
		t.Fatalf("SendLiveEvent error = %v, want nil", err)
	}
	if got := svc.ResolvedSessionStatus("sid-1"); got != domain.SessionStatusWaitingApproval {
		t.Fatalf("status = %q, want %q", got, domain.SessionStatusWaitingApproval)
	}
	stats := transport.statsSnapshot()
	if stats.RelayExpectedDrops != 1 || stats.RelayErrors != 0 {
		t.Fatalf("transport stats = %+v, want one expected relay drop", stats)
	}
}

func TestLocalAgentChatTransportDoesNotGateBufferedEventsOnExpectedRelayDrop(t *testing.T) {
	buf := agentchat.NewEventBuffer(8)
	transport := &localAgentChatTransport{
		relay: fakeEventTransport{err: relayws.ErrRelayNotConnected},
		local: newLocalEventBroker(buf),
	}
	svc := agentchat.New(agentchat.Config{
		EventBuffer: buf,
		Transport:   transport,
	})

	err := svc.SendEvent(appwire.Event{
		Type:      appwire.EventRunFailed,
		SessionID: "sid-1",
	})
	if err != nil {
		t.Fatalf("SendEvent error = %v, want nil", err)
	}
	if buf.Seq() != 1 {
		t.Fatalf("buffer seq = %d, want 1", buf.Seq())
	}
	if got := svc.ResolvedSessionStatus("sid-1"); got != domain.SessionStatusError {
		t.Fatalf("status = %q, want %q", got, domain.SessionStatusError)
	}
	stats := transport.statsSnapshot()
	if stats.RelayExpectedDrops != 1 || stats.RelayErrors != 0 {
		t.Fatalf("transport stats = %+v, want one expected relay drop", stats)
	}
}

func TestLocalAgentChatTransportDoesNotGateLiveEventsOnRelayErrorWhenLocalAvailable(t *testing.T) {
	relayErr := errors.New("relay write failed")
	transport := &localAgentChatTransport{
		relay: fakeEventTransport{err: relayErr},
		local: newLocalEventBroker(agentchat.NewEventBuffer(8)),
	}
	svc := agentchat.New(agentchat.Config{Transport: transport})

	err := svc.SendLiveEvent(appwire.Event{
		Type:      appwire.EventSessionStatus,
		SessionID: "sid-1",
		SessionInfo: &appwire.SessionStatusEvent{
			App: appwire.SessionStatusEventApp{ID: "sid-1", Status: appwire.SessionStatusRunning},
		},
	})
	if err != nil {
		t.Fatalf("SendLiveEvent error = %v, want nil", err)
	}
	if got := svc.ResolvedSessionStatus("sid-1"); got != domain.SessionStatusRunning {
		t.Fatalf("status = %q, want %q", got, domain.SessionStatusRunning)
	}
	stats := transport.statsSnapshot()
	if stats.RelayErrors != 1 || stats.RelayExpectedDrops != 0 || stats.LastRelayError != relayErr.Error() {
		t.Fatalf("transport stats = %+v, want one relay error", stats)
	}
}

func TestLocalAgentChatTransportDoesNotGateBufferedEventsOnRelayErrorWhenLocalAvailable(t *testing.T) {
	relayErr := errors.New("relay write failed")
	buf := agentchat.NewEventBuffer(8)
	transport := &localAgentChatTransport{
		relay: fakeEventTransport{err: relayErr},
		local: newLocalEventBroker(buf),
	}
	svc := agentchat.New(agentchat.Config{EventBuffer: buf, Transport: transport})

	err := svc.SendEvent(appwire.Event{
		Type:      appwire.EventRunFailed,
		SessionID: "sid-1",
	})
	if err != nil {
		t.Fatalf("SendEvent error = %v, want nil", err)
	}
	if got := buf.Seq(); got != 1 {
		t.Fatalf("buffer seq = %d, want 1", got)
	}
	if got := svc.ResolvedSessionStatus("sid-1"); got != domain.SessionStatusError {
		t.Fatalf("status = %q, want %q", got, domain.SessionStatusError)
	}
	stats := transport.statsSnapshot()
	if stats.RelayErrors != 1 || stats.RelayExpectedDrops != 0 || stats.LastRelayError != relayErr.Error() {
		t.Fatalf("transport stats = %+v, want one relay error", stats)
	}
}

func TestLocalAgentChatTransportReturnsRelayErrorWithoutLocalBroker(t *testing.T) {
	relayErr := errors.New("relay write failed")
	svc := agentchat.New(agentchat.Config{
		Transport: &localAgentChatTransport{relay: fakeEventTransport{err: relayErr}},
	})

	err := svc.SendLiveEvent(appwire.Event{
		Type:      appwire.EventSessionStatus,
		SessionID: "sid-1",
		SessionInfo: &appwire.SessionStatusEvent{
			App: appwire.SessionStatusEventApp{ID: "sid-1", Status: appwire.SessionStatusRunning},
		},
	})
	if !errors.Is(err, relayErr) {
		t.Fatalf("SendLiveEvent error = %v, want %v", err, relayErr)
	}
	if got := svc.ResolvedSessionStatus("sid-1"); got != domain.SessionStatusIdle {
		t.Fatalf("status = %q, want unchanged idle", got)
	}
}

func TestLocalEventBrokerDropsFullSubscriberWithStats(t *testing.T) {
	broker := newLocalEventBroker(nil)
	broker.subscriberBuffer = 1
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	_, live := broker.subscribe(ctx, 0, 0)

	broker.publishLive(appwire.Event{Type: appwire.EventMessageDelta, SessionID: "sid-1"})
	broker.publishLive(appwire.Event{Type: appwire.EventMessageDelta, SessionID: "sid-1"})

	select {
	case _, ok := <-live:
		if !ok {
			t.Fatal("subscriber closed before receiving buffered event")
		}
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for first buffered event")
	}
	select {
	case _, ok := <-live:
		if ok {
			t.Fatal("subscriber still open after full queue drop")
		}
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for subscriber close")
	}
	stats := broker.statsSnapshot()
	if stats.SubscriberDrops != 1 || stats.ActiveSubscribers != 0 {
		t.Fatalf("broker stats = %+v, want one dropped subscriber and zero active", stats)
	}
}
