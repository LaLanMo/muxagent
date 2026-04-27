package control

import (
	"encoding/json"

	"github.com/LaLanMo/muxagent/cli/internal/appwire"
)

type AgentChatRPCRequest struct {
	Method string          `json:"method"`
	Params json.RawMessage `json:"params,omitempty"`
}

type AgentChatRPCResponse struct {
	Result json.RawMessage `json:"result,omitempty"`
	Error  string          `json:"error,omitempty"`
	Events []appwire.Event `json:"events,omitempty"`
}
