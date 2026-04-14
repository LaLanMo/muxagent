package acp

import (
	"encoding/json"
	"testing"
)

func TestIncomingMessageSupportsStringIDs(t *testing.T) {
	var msg IncomingMessage
	payload := []byte(`{"jsonrpc":"2.0","id":"call_123","method":"session/request_permission","params":{}}`)
	if err := json.Unmarshal(payload, &msg); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if !msg.IsRequest() {
		t.Fatal("expected message to be treated as a request")
	}
	if got := msg.IDString(); got != "call_123" {
		t.Fatalf("IDString = %q, want call_123", got)
	}
	if _, ok := msg.Int64ID(); ok {
		t.Fatal("expected string ID to remain non-numeric")
	}
}

func TestIncomingMessageSupportsNumericIDs(t *testing.T) {
	var msg IncomingMessage
	payload := []byte(`{"jsonrpc":"2.0","id":42,"result":{}}`)
	if err := json.Unmarshal(payload, &msg); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if !msg.IsResponse() {
		t.Fatal("expected message to be treated as a response")
	}
	if got, ok := msg.Int64ID(); !ok || got != 42 {
		t.Fatalf("Int64ID = (%d, %v), want (42, true)", got, ok)
	}
	if got := msg.IDString(); got != "42" {
		t.Fatalf("IDString = %q, want 42", got)
	}
}
