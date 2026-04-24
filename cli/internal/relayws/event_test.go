package relayws

import (
	"testing"
	"time"

	"github.com/LaLanMo/muxagent/cli/internal/appwire"
)

func makeEvent(typ appwire.EventType) appwire.Event {
	return appwire.Event{Type: typ, At: time.Now()}
}

func TestEventBufferShimUsesAgentChatBuffer(t *testing.T) {
	buf := NewEventBuffer(1)
	first := buf.Push(makeEvent(appwire.EventMessageDelta))
	if first.Seq != 1 {
		t.Fatalf("first Seq = %d, want 1", first.Seq)
	}
}
