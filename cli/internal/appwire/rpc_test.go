package appwire

import (
	"bytes"
	"encoding/json"
	"testing"
)

func TestRPCResponseJSONRoundTrip(t *testing.T) {
	raw := json.RawMessage(`{"ok":true}`)
	resp := RPCResponse{Result: raw}

	payload, err := json.Marshal(resp)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}
	var decoded RPCResponse
	if err := json.Unmarshal(payload, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}
	if string(decoded.Result) != string(raw) {
		t.Fatalf("result = %s, want %s", decoded.Result, raw)
	}
}

func TestSessionLoadResultReplayShape(t *testing.T) {
	result := SessionLoadResult{
		App: SessionLoadResultApp{
			OK:        true,
			SessionID: "sid",
			Runtime:   "codex",
			CWD:       "/tmp/project",
			Replay: SessionLoadReplay{
				Events:   []Event{},
				Complete: true,
			},
		},
	}

	payload, err := json.Marshal(result)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}
	if !json.Valid(payload) {
		t.Fatalf("invalid json: %s", payload)
	}
	if bytes.Contains(payload, []byte(`"updatedAt"`)) {
		t.Fatalf("session.load without metadata should omit updatedAt: %s", payload)
	}
	var decoded SessionLoadResult
	if err := json.Unmarshal(payload, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}
	if decoded.App.Replay.Events == nil {
		t.Fatalf("replay events nil, want empty slice")
	}
	if !decoded.App.Replay.Complete {
		t.Fatal("replay complete = false, want true")
	}
}
