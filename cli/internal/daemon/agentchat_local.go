package daemon

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"sync"

	"github.com/LaLanMo/muxagent/cli/internal/agentchat"
	"github.com/LaLanMo/muxagent/cli/internal/appwire"
	"github.com/LaLanMo/muxagent/cli/internal/control"
)

type localAgentChatTransport struct {
	relay agentchat.EventTransport
	local *localEventBroker

	mu    sync.Mutex
	stats localAgentChatTransportStats
}

type localAgentChatTransportStats struct {
	RelayExpectedDrops uint64
	RelayErrors        uint64
	LastRelayError     string
}

func (t *localAgentChatTransport) DeliverEvent(event appwire.Event) error {
	localAvailable := t != nil && t.local != nil
	if localAvailable {
		t.local.publishBuffered(event)
	}
	if t == nil || t.relay == nil {
		if localAvailable {
			return nil
		}
		return agentchat.ErrEventTransportUnavailable
	}
	err := t.relay.DeliverEvent(event)
	if err != nil && localAvailable {
		t.recordRelayError(err)
		return nil
	}
	return err
}

func (t *localAgentChatTransport) DeliverLiveEvent(event appwire.Event) error {
	localAvailable := t != nil && t.local != nil
	if localAvailable {
		t.local.publishLive(event)
	}
	if t == nil || t.relay == nil {
		if localAvailable {
			return nil
		}
		return agentchat.ErrEventTransportUnavailable
	}
	err := t.relay.DeliverLiveEvent(event)
	if err != nil && localAvailable {
		t.recordRelayError(err)
		return nil
	}
	return err
}

func (t *localAgentChatTransport) recordRelayError(err error) {
	if t == nil || err == nil {
		return
	}
	t.mu.Lock()
	defer t.mu.Unlock()
	if isExpectedRelayDrop(err) {
		t.stats.RelayExpectedDrops++
	} else {
		t.stats.RelayErrors++
	}
	t.stats.LastRelayError = err.Error()
}

func (t *localAgentChatTransport) statsSnapshot() localAgentChatTransportStats {
	if t == nil {
		return localAgentChatTransportStats{}
	}
	t.mu.Lock()
	defer t.mu.Unlock()
	return t.stats
}

const localEventSubscriberBuffer = 256

type localEventBroker struct {
	buffer *agentchat.EventBuffer

	mu               sync.Mutex
	subscribers      map[*localEventSubscriber]struct{}
	subscriberBuffer int
	stats            localEventBrokerStats
}

type localEventBrokerStats struct {
	ActiveSubscribers uint64
	SubscriberDrops   uint64
}

type localEventSubscriber struct {
	ch       chan appwire.Event
	afterSeq uint64
}

func newLocalEventBroker(buffer *agentchat.EventBuffer) *localEventBroker {
	return &localEventBroker{
		buffer:           buffer,
		subscribers:      make(map[*localEventSubscriber]struct{}),
		subscriberBuffer: localEventSubscriberBuffer,
	}
}

func (b *localEventBroker) subscribe(ctx context.Context, streamEpoch, afterSeq uint64) ([]appwire.Event, <-chan appwire.Event) {
	if b == nil {
		ch := make(chan appwire.Event)
		close(ch)
		return nil, ch
	}

	b.mu.Lock()
	defer b.mu.Unlock()

	replayedThroughSeq := afterSeq
	var initial []appwire.Event
	if b.buffer != nil {
		snapshot := b.buffer.ReplaySince(streamEpoch, afterSeq)
		initial = snapshot.Events
		replayedThroughSeq = snapshot.ReplayedThroughSeq
	}

	sub := &localEventSubscriber{
		ch:       make(chan appwire.Event, b.resolvedSubscriberBuffer()),
		afterSeq: replayedThroughSeq,
	}
	b.subscribers[sub] = struct{}{}
	go func() {
		<-ctx.Done()
		b.remove(sub)
	}()
	return initial, sub.ch
}

func (b *localEventBroker) publishBuffered(event appwire.Event) {
	if b == nil {
		return
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	for sub := range b.subscribers {
		if event.Seq <= sub.afterSeq {
			continue
		}
		select {
		case sub.ch <- event:
			sub.afterSeq = event.Seq
		default:
			b.dropSubscriberLocked(sub)
		}
	}
}

func (b *localEventBroker) publishLive(event appwire.Event) {
	if b == nil {
		return
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	for sub := range b.subscribers {
		select {
		case sub.ch <- event:
		default:
			b.dropSubscriberLocked(sub)
		}
	}
}

func (b *localEventBroker) remove(sub *localEventSubscriber) {
	b.mu.Lock()
	defer b.mu.Unlock()
	if _, ok := b.subscribers[sub]; !ok {
		return
	}
	delete(b.subscribers, sub)
	close(sub.ch)
}

func (b *localEventBroker) dropSubscriberLocked(sub *localEventSubscriber) {
	if b == nil || sub == nil {
		return
	}
	if _, ok := b.subscribers[sub]; !ok {
		return
	}
	delete(b.subscribers, sub)
	close(sub.ch)
	b.stats.SubscriberDrops++
}

func (b *localEventBroker) resolvedSubscriberBuffer() int {
	if b == nil || b.subscriberBuffer <= 0 {
		return localEventSubscriberBuffer
	}
	return b.subscriberBuffer
}

func (b *localEventBroker) statsSnapshot() localEventBrokerStats {
	if b == nil {
		return localEventBrokerStats{}
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	stats := b.stats
	stats.ActiveSubscribers = uint64(len(b.subscribers))
	return stats
}

func (d *Daemon) handleAgentChatRPC(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		control.WriteJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	if d.chat == nil {
		control.WriteJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "agentchat unavailable"})
		return
	}

	var req control.AgentChatRPCRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		control.WriteJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	if strings.TrimSpace(req.Method) == "" {
		control.WriteJSON(w, http.StatusBadRequest, map[string]string{"error": "method is required"})
		return
	}

	var scopedEvents []appwire.Event
	ctx := agentchat.WithScopedEventSink(r.Context(), func(event appwire.Event) {
		scopedEvents = append(scopedEvents, event)
	})
	result, errStr := d.chat.HandleRPC(ctx, appwire.RPCRequest{
		Method: strings.TrimSpace(req.Method),
		Params: req.Params,
	})
	var raw json.RawMessage
	if result != nil {
		payload, err := json.Marshal(result)
		if err != nil {
			control.WriteJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
			return
		}
		raw = payload
	}
	control.WriteJSON(w, http.StatusOK, control.AgentChatRPCResponse{
		Result: raw,
		Error:  errStr,
		Events: scopedEvents,
	})
}

func (d *Daemon) handleAgentChatEvents(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		control.WriteJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	if d.localEvents == nil {
		control.WriteJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "agentchat events unavailable"})
		return
	}
	flusher, ok := w.(http.Flusher)
	if !ok {
		control.WriteJSON(w, http.StatusInternalServerError, map[string]string{"error": "streaming unsupported"})
		return
	}

	streamEpoch := parseUintQuery(r, "streamEpoch")
	afterSeq := parseUintQuery(r, "afterSeq")
	initial, events := d.localEvents.subscribe(r.Context(), streamEpoch, afterSeq)

	w.Header().Set("Content-Type", "application/x-ndjson")
	w.Header().Set("Cache-Control", "no-cache")
	flusher.Flush()
	encoder := json.NewEncoder(w)
	writeEvent := func(event appwire.Event) bool {
		if err := encoder.Encode(event); err != nil {
			return false
		}
		flusher.Flush()
		return true
	}
	for _, event := range initial {
		if !writeEvent(event) {
			return
		}
	}
	for {
		select {
		case event, ok := <-events:
			if !ok {
				return
			}
			if !writeEvent(event) {
				return
			}
		case <-r.Context().Done():
			return
		}
	}
}

func parseUintQuery(r *http.Request, key string) uint64 {
	value := strings.TrimSpace(r.URL.Query().Get(key))
	if value == "" {
		return 0
	}
	parsed, err := strconv.ParseUint(value, 10, 64)
	if err != nil {
		return 0
	}
	return parsed
}
