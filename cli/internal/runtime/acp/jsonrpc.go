package acp

import (
	"encoding/json"
	"errors"
	"math"
	"strconv"
)

// Request is a JSON-RPC 2.0 request sent from client to agent.
type Request struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      int64           `json:"id"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params,omitempty"`
}

// Response is a JSON-RPC 2.0 response received from agent.
type Response struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      int64           `json:"id"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   *RPCError       `json:"error,omitempty"`
}

// Notification is a JSON-RPC 2.0 notification (no ID) from agent to client.
type Notification struct {
	JSONRPC string          `json:"jsonrpc"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params,omitempty"`
}

// RPCError is a JSON-RPC 2.0 error object.
type RPCError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

func (e *RPCError) Error() string {
	return e.Message
}

func IsMethodNotFoundError(err error) bool {
	var rpcErr *RPCError
	return errors.As(err, &rpcErr) && rpcErr.Code == -32601
}

// IncomingMessage is a union type for parsing any incoming JSON-RPC message.
// Discriminate by checking: has ID+Result/Error → Response; has Method+no ID → Notification; has Method+ID → Request.
type IncomingMessage struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      any             `json:"id,omitempty"`
	Method  string          `json:"method,omitempty"`
	Params  json.RawMessage `json:"params,omitempty"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   *RPCError       `json:"error,omitempty"`
}

// IsResponse returns true if this message is a response (has ID, has result or error, no method).
func (m *IncomingMessage) IsResponse() bool {
	return m.ID != nil && m.Method == ""
}

// IsNotification returns true if this message is a notification (has method, no ID).
func (m *IncomingMessage) IsNotification() bool {
	return m.Method != "" && m.ID == nil
}

// IsRequest returns true if this message is a request from agent (has method and ID).
func (m *IncomingMessage) IsRequest() bool {
	return m.Method != "" && m.ID != nil
}

func (m *IncomingMessage) Int64ID() (int64, bool) {
	switch id := m.ID.(type) {
	case nil:
		return 0, false
	case float64:
		if math.Trunc(id) != id {
			return 0, false
		}
		return int64(id), true
	case int64:
		return id, true
	case int:
		return int64(id), true
	case string:
		value, err := strconv.ParseInt(id, 10, 64)
		if err != nil {
			return 0, false
		}
		return value, true
	default:
		return 0, false
	}
}

func (m *IncomingMessage) IDValue() any {
	return m.ID
}

func (m *IncomingMessage) IDString() string {
	switch id := m.ID.(type) {
	case nil:
		return ""
	case string:
		return id
	case float64:
		if math.Trunc(id) == id {
			return strconv.FormatInt(int64(id), 10)
		}
		return strconv.FormatFloat(id, 'f', -1, 64)
	case int64:
		return strconv.FormatInt(id, 10)
	case int:
		return strconv.Itoa(id)
	default:
		return ""
	}
}
