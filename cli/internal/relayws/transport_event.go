package relayws

import (
	"github.com/LaLanMo/muxagent/cli/internal/agentchat"
	"github.com/LaLanMo/muxagent/cli/internal/appwire"
)

func normalizeEventForTransport(event appwire.Event) appwire.Event {
	return agentchat.NormalizeEventForTransport(event)
}
