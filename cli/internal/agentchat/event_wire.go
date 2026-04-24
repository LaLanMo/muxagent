package agentchat

import (
	"encoding/json"

	"github.com/LaLanMo/muxagent/cli/internal/appwire"
)

func MarshalEvent(event appwire.Event) ([]byte, error) {
	return json.Marshal(event)
}
