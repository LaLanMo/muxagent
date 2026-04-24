package agentchat

import (
	"errors"
	"testing"
	"time"

	"github.com/LaLanMo/muxagent/cli/internal/appwire"
	"github.com/LaLanMo/muxagent/cli/internal/domain"
)

type recordingTransport struct {
	eventErr error
	liveErr  error
	events   []appwire.Event
	live     []appwire.Event
}

func (t *recordingTransport) DeliverEvent(event appwire.Event) error {
	t.events = append(t.events, event)
	return t.eventErr
}

func (t *recordingTransport) DeliverLiveEvent(event appwire.Event) error {
	t.live = append(t.live, event)
	return t.liveErr
}

func TestServiceSendEventBuffersAndTracksStatusBeforeTransport(t *testing.T) {
	transportErr := errors.New("offline")
	buf := NewEventBuffer(8)
	transport := &recordingTransport{eventErr: transportErr}
	svc := New(Config{EventBuffer: buf, Transport: transport})

	err := svc.SendEvent(appwire.Event{
		Type:      appwire.EventApprovalRequested,
		SessionID: "sid",
		At:        time.Now(),
		Approval:  &appwire.ApprovalRequest{App: appwire.ApprovalApp{RequestID: "req-1"}},
	})

	if !errors.Is(err, transportErr) {
		t.Fatalf("SendEvent error = %v, want %v", err, transportErr)
	}
	if got := svc.ResolvedSessionStatus("sid"); got != domain.SessionStatusWaitingApproval {
		t.Fatalf("status = %q, want %q", got, domain.SessionStatusWaitingApproval)
	}
	snapshot := buf.ReplaySince(buf.StreamEpoch(), 0)
	if len(snapshot.Events) != 1 {
		t.Fatalf("buffered events = %d, want 1", len(snapshot.Events))
	}
	if snapshot.Events[0].Seq != 1 {
		t.Fatalf("buffered Seq = %d, want 1", snapshot.Events[0].Seq)
	}
	if len(transport.events) != 1 || transport.events[0].Seq != 1 {
		t.Fatalf("transport events = %#v, want one seq=1 event", transport.events)
	}
}

func TestServiceSendLiveEventDoesNotBufferOrTrackStatusOnTransportFailure(t *testing.T) {
	transportErr := errors.New("no active phone")
	buf := NewEventBuffer(8)
	transport := &recordingTransport{liveErr: transportErr}
	svc := New(Config{EventBuffer: buf, Transport: transport})

	err := svc.SendLiveEvent(appwire.Event{
		Type:      appwire.EventSessionStatus,
		SessionID: "sid",
		At:        time.Now(),
		SessionInfo: &appwire.SessionStatusEvent{
			App: appwire.SessionStatusEventApp{ID: "sid", Status: appwire.SessionStatusRunning},
		},
	})

	if !errors.Is(err, transportErr) {
		t.Fatalf("SendLiveEvent error = %v, want %v", err, transportErr)
	}
	if got := svc.ResolvedSessionStatus("sid"); got != domain.SessionStatusIdle {
		t.Fatalf("status = %q, want %q", got, domain.SessionStatusIdle)
	}
	snapshot := buf.ReplaySince(buf.StreamEpoch(), 0)
	if len(snapshot.Events) != 0 {
		t.Fatalf("buffered live events = %d, want 0", len(snapshot.Events))
	}
}

func TestServiceSendLiveEventTracksStatusAfterTransportSuccess(t *testing.T) {
	buf := NewEventBuffer(8)
	svc := New(Config{EventBuffer: buf, Transport: &recordingTransport{}})

	err := svc.SendLiveEvent(appwire.Event{
		Type:      appwire.EventSessionStatus,
		SessionID: "sid",
		At:        time.Now(),
		SessionInfo: &appwire.SessionStatusEvent{
			App: appwire.SessionStatusEventApp{ID: "sid", Status: appwire.SessionStatusRunning},
		},
	})

	if err != nil {
		t.Fatalf("SendLiveEvent error = %v, want nil", err)
	}
	if got := svc.ResolvedSessionStatus("sid"); got != domain.SessionStatusRunning {
		t.Fatalf("status = %q, want %q", got, domain.SessionStatusRunning)
	}
	snapshot := buf.ReplaySince(buf.StreamEpoch(), 0)
	if len(snapshot.Events) != 0 {
		t.Fatalf("buffered live events = %d, want 0", len(snapshot.Events))
	}
}
