package relayws

import (
	"github.com/LaLanMo/muxagent/cli/internal/agentchat"
	"github.com/LaLanMo/muxagent/cli/internal/appwire"
)

func marshalEvent(event appwire.Event) ([]byte, error) {
	return agentchat.MarshalEvent(event)
}
