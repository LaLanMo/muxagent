package agentchat

import (
	"crypto/rand"
	"encoding/binary"
	"sync"
	"sync/atomic"

	"github.com/LaLanMo/muxagent/cli/internal/appwire"
)

// EventBuffer is a fixed-size ring buffer for app transport events.
// Each pushed event is assigned a monotonically increasing sequence number.
type EventBuffer struct {
	mu          sync.RWMutex
	events      []appwire.Event
	eventSizes  []int
	size        int
	head        int // next write position
	count       int // number of events stored
	bytesUsed   int
	byteBudget  int
	seq         uint64
	streamEpoch uint64
}

type ReplaySnapshot struct {
	Events             []appwire.Event
	Status             appwire.ResyncStatus
	StreamEpoch        uint64
	ReplayedThroughSeq uint64
}

type ReplayPageSnapshot struct {
	Events             []appwire.Event
	Status             appwire.ResyncStatus
	StreamEpoch        uint64
	ReplayedThroughSeq uint64
	HasMore            bool
	NextAfterSeq       uint64
}

var fallbackStreamEpoch uint64

const maxJSONSafeInteger = uint64(1<<53 - 1)

func NewEventBuffer(size int) *EventBuffer {
	return NewEventBufferWithByteBudget(size, DefaultEventBufferByteBudget)
}

func NewEventBufferWithByteBudget(size, byteBudget int) *EventBuffer {
	if size <= 0 {
		size = 1024
	}
	return &EventBuffer{
		events:      make([]appwire.Event, size),
		eventSizes:  make([]int, size),
		size:        size,
		byteBudget:  byteBudget,
		streamEpoch: nextStreamEpoch(),
	}
}

// Push assigns a sequence number to the event, stores it in the ring buffer,
// and returns the event with the assigned Seq.
func (b *EventBuffer) Push(event appwire.Event) appwire.Event {
	b.mu.Lock()
	defer b.mu.Unlock()

	b.seq++
	event.Seq = b.seq
	eventSize := 1
	if encoded, err := MarshalEvent(event); err == nil && len(encoded) > 0 {
		eventSize = len(encoded)
	}

	if b.count == b.size {
		b.bytesUsed -= b.eventSizes[b.head]
	} else {
		b.count++
	}

	b.events[b.head] = event
	b.eventSizes[b.head] = eventSize
	b.bytesUsed += eventSize
	b.head = (b.head + 1) % b.size
	if b.byteBudget > 0 {
		for b.count > 0 && b.bytesUsed > b.byteBudget {
			b.dropOldestLocked()
		}
	}

	return event
}

// ReplaySince returns an atomic replay snapshot for the requested cursor.
func (b *EventBuffer) ReplaySince(streamEpoch, afterSeq uint64) ReplaySnapshot {
	b.mu.RLock()
	defer b.mu.RUnlock()

	return b.replaySinceLocked(streamEpoch, afterSeq)
}

// ReplaySincePage returns an atomic replay snapshot page for the requested cursor.
func (b *EventBuffer) ReplaySincePage(streamEpoch, afterSeq uint64, maxBytes, maxEvents int) ReplayPageSnapshot {
	b.mu.RLock()
	defer b.mu.RUnlock()

	snapshot := b.replaySinceLocked(streamEpoch, afterSeq)
	page := ReplayPageSnapshot{
		Events:             make([]appwire.Event, 0),
		Status:             snapshot.Status,
		StreamEpoch:        snapshot.StreamEpoch,
		ReplayedThroughSeq: snapshot.ReplayedThroughSeq,
		NextAfterSeq:       afterSeq,
	}

	if len(snapshot.Events) == 0 {
		return page
	}

	if maxEvents <= 0 {
		maxEvents = len(snapshot.Events)
	}

	bytesUsed := 0
	for _, event := range snapshot.Events {
		if len(page.Events) >= maxEvents {
			page.HasMore = true
			break
		}

		eventSize := 1
		if encoded, err := MarshalEvent(event); err == nil && len(encoded) > 0 {
			eventSize = len(encoded)
		}

		if len(page.Events) > 0 && maxBytes > 0 && bytesUsed+eventSize > maxBytes {
			page.HasMore = true
			break
		}

		page.Events = append(page.Events, event)
		page.NextAfterSeq = event.Seq
		bytesUsed += eventSize
	}

	if !page.HasMore && len(page.Events) < len(snapshot.Events) {
		page.HasMore = true
	}

	return page
}

// Reset clears buffered history and advances the replay stream epoch.
func (b *EventBuffer) Reset() uint64 {
	b.mu.Lock()
	defer b.mu.Unlock()

	clear(b.events)
	clear(b.eventSizes)
	b.head = 0
	b.count = 0
	b.bytesUsed = 0
	b.seq = 0
	b.streamEpoch = nextStreamEpoch()

	return b.streamEpoch
}

// Seq returns the current (latest) sequence number.
func (b *EventBuffer) Seq() uint64 {
	b.mu.RLock()
	defer b.mu.RUnlock()
	return b.seq
}

// StreamEpoch returns the current replay stream epoch.
func (b *EventBuffer) StreamEpoch() uint64 {
	b.mu.RLock()
	defer b.mu.RUnlock()
	return b.streamEpoch
}

func (b *EventBuffer) snapshotAllLocked() []appwire.Event {
	if b.count == 0 {
		return make([]appwire.Event, 0)
	}

	oldestIdx := (b.head - b.count + b.size) % b.size
	result := make([]appwire.Event, 0, b.count)
	for i := 0; i < b.count; i++ {
		idx := (oldestIdx + i) % b.size
		result = append(result, b.events[idx])
	}
	return result
}

func (b *EventBuffer) replaySinceLocked(streamEpoch, afterSeq uint64) ReplaySnapshot {
	snapshot := ReplaySnapshot{
		Events:             make([]appwire.Event, 0),
		Status:             appwire.ResyncStatusOK,
		StreamEpoch:        b.streamEpoch,
		ReplayedThroughSeq: b.seq,
	}

	if streamEpoch == 0 || streamEpoch != b.streamEpoch {
		snapshot.Status = appwire.ResyncStatusReset
		snapshot.Events = b.snapshotAllLocked()
		return snapshot
	}

	if afterSeq > b.seq {
		snapshot.Status = appwire.ResyncStatusReset
		snapshot.Events = b.snapshotAllLocked()
		return snapshot
	}

	if b.count == 0 || afterSeq == b.seq {
		return snapshot
	}

	oldestIdx := (b.head - b.count + b.size) % b.size
	oldestSeq := b.events[oldestIdx].Seq

	if afterSeq < oldestSeq-1 {
		snapshot.Status = appwire.ResyncStatusGap
		snapshot.Events = b.snapshotAllLocked()
		return snapshot
	}

	result := make([]appwire.Event, 0, b.count)
	for i := 0; i < b.count; i++ {
		idx := (oldestIdx + i) % b.size
		if b.events[idx].Seq > afterSeq {
			result = append(result, b.events[idx])
		}
	}
	snapshot.Events = result
	return snapshot
}

func (b *EventBuffer) dropOldestLocked() {
	if b.count == 0 {
		return
	}
	oldestIdx := (b.head - b.count + b.size) % b.size
	b.bytesUsed -= b.eventSizes[oldestIdx]
	if b.bytesUsed < 0 {
		b.bytesUsed = 0
	}
	b.events[oldestIdx] = appwire.Event{}
	b.eventSizes[oldestIdx] = 0
	b.count--
}

func nextStreamEpoch() uint64 {
	var raw [8]byte
	if _, err := rand.Read(raw[:]); err == nil {
		if epoch := jsonSafeEpoch(binary.LittleEndian.Uint64(raw[:])); epoch != 0 {
			return epoch
		}
	}

	return jsonSafeEpoch(atomic.AddUint64(&fallbackStreamEpoch, 1))
}

func jsonSafeEpoch(value uint64) uint64 {
	epoch := value & maxJSONSafeInteger
	if epoch == 0 {
		return 1
	}
	return epoch
}
