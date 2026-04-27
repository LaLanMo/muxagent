package daemon

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/LaLanMo/muxagent/cli/internal/appwire"
	"github.com/LaLanMo/muxagent/cli/internal/control"
)

func TestDaemonStopClosesDoneChannel(t *testing.T) {
	d := New("ws://localhost:8080/ws")

	if err := d.Stop(context.Background()); err != nil {
		t.Fatalf("Stop returned error: %v", err)
	}

	select {
	case <-d.Done():
	case <-time.After(time.Second):
		t.Fatal("daemon done channel was not closed")
	}

	if err := d.Stop(context.Background()); err != nil {
		t.Fatalf("second Stop returned error: %v", err)
	}
}

func TestLocalMachineIDPersists(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)

	first, err := localMachineID()
	if err != nil {
		t.Fatalf("localMachineID first: %v", err)
	}
	second, err := localMachineID()
	if err != nil {
		t.Fatalf("localMachineID second: %v", err)
	}
	if first != second {
		t.Fatalf("local machine id changed: first=%q second=%q", first, second)
	}
	if !strings.HasPrefix(first, "local-") {
		t.Fatalf("local machine id = %q, want local-*", first)
	}
	info, err := os.Stat(filepath.Join(home, ".muxagent", localMachineIDFileName))
	if err != nil {
		t.Fatalf("local machine id file: %v", err)
	}
	if got := info.Mode().Perm(); got != 0o600 {
		t.Fatalf("local machine id permissions = %04o, want 0600", got)
	}
}

func TestDaemonStartWithoutCredentialsStartsLocalAgentChat(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)

	d := New("ws://127.0.0.1:1/ws")
	if err := d.Start(); err != nil {
		t.Fatalf("Start without credentials: %v", err)
	}
	defer func() {
		if err := d.Stop(context.Background()); err != nil {
			t.Fatalf("Stop: %v", err)
		}
	}()

	if d.relay != nil {
		t.Fatal("relay client = non-nil without credentials")
	}
	if d.chat == nil {
		t.Fatal("chat service = nil")
	}
	if got := d.chat.MachineID(); !strings.HasPrefix(got, "local-") {
		t.Fatalf("machine id = %q, want local-*", got)
	}
	healthReq, err := http.NewRequest(http.MethodGet, "http://"+d.Address()+"/health", nil)
	if err != nil {
		t.Fatalf("health NewRequest: %v", err)
	}
	healthReq.Header.Set("Authorization", "Bearer "+d.Token())
	healthResp, err := http.DefaultClient.Do(healthReq)
	if err != nil {
		t.Fatalf("health request: %v", err)
	}
	defer healthResp.Body.Close()
	var health struct {
		InstanceID string `json:"instance_id"`
	}
	if err := json.NewDecoder(healthResp.Body).Decode(&health); err != nil {
		t.Fatalf("Decode health: %v", err)
	}
	if health.InstanceID == "" || health.InstanceID != d.InstanceID() {
		t.Fatalf("health instance_id = %q, want %q", health.InstanceID, d.InstanceID())
	}

	body, err := json.Marshal(control.AgentChatRPCRequest{Method: "events.head"})
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}
	req, err := http.NewRequest(
		http.MethodPost,
		"http://"+d.Address()+"/agentchat/rpc",
		bytes.NewReader(body),
	)
	if err != nil {
		t.Fatalf("NewRequest: %v", err)
	}
	req.Header.Set("Authorization", "Bearer "+d.Token())
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("agentchat rpc request: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %s, want 200", resp.Status)
	}
	var envelope control.AgentChatRPCResponse
	if err := json.NewDecoder(resp.Body).Decode(&envelope); err != nil {
		t.Fatalf("Decode envelope: %v", err)
	}
	if envelope.Error != "" {
		t.Fatalf("agentchat error = %q, want empty", envelope.Error)
	}
	var head appwire.ReplayHeadResult
	if err := json.Unmarshal(envelope.Result, &head); err != nil {
		t.Fatalf("Unmarshal head: %v", err)
	}
	if head.StreamEpoch == 0 {
		t.Fatal("streamEpoch = 0, want non-zero")
	}
}
