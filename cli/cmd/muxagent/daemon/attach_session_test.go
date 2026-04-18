package daemon

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/LaLanMo/muxagent/cli/internal/control"
)

func TestSendAttachSessionRequest(t *testing.T) {
	var received control.AttachSessionRequest
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if got := r.Header.Get("Authorization"); got != "Bearer secret-token" {
			t.Fatalf("authorization = %q, want Bearer secret-token", got)
		}
		if got := r.URL.Path; got != "/remote/attach-session" {
			t.Fatalf("path = %q, want /remote/attach-session", got)
		}
		if err := json.NewDecoder(r.Body).Decode(&received); err != nil {
			t.Fatalf("decode request: %v", err)
		}
		control.WriteJSON(w, http.StatusOK, control.AttachSessionResponse{
			OK:          true,
			SessionID:   "sid-1",
			Runtime:     "codex",
			CWD:         "/tmp/project",
			Title:       "Attached title",
			Status:      "idle",
			Broadcasted: true,
		})
	}))
	defer server.Close()

	resp, err := sendAttachSessionRequestWithToken(
		context.Background(),
		strings.TrimPrefix(server.URL, "http://"),
		"secret-token",
		control.AttachSessionRequest{
			SessionID: "sid-1",
			Runtime:   "codex",
		},
		server.Client(),
	)
	if err != nil {
		t.Fatalf("sendAttachSessionRequest: %v", err)
	}
	if received.SessionID != "sid-1" {
		t.Fatalf("sessionID = %q, want sid-1", received.SessionID)
	}
	if received.Runtime != "codex" {
		t.Fatalf("runtime = %q, want codex", received.Runtime)
	}
	if resp.Runtime != "codex" {
		t.Fatalf("runtime = %q, want codex", resp.Runtime)
	}
}

func TestSendAttachSessionRequestReturnsServerErrorMessage(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		control.WriteJSON(w, http.StatusNotFound, map[string]string{
			"error": "session not found in local codex transcript store",
		})
	}))
	defer server.Close()

	_, err := sendAttachSessionRequestWithToken(
		context.Background(),
		strings.TrimPrefix(server.URL, "http://"),
		"secret-token",
		control.AttachSessionRequest{
			SessionID: "missing",
			Runtime:   "codex",
		},
		server.Client(),
	)
	if err == nil {
		t.Fatal("expected error")
	}
	if !strings.Contains(err.Error(), "session not found") {
		t.Fatalf("error = %v, want propagated server message", err)
	}
}

func TestAttachSessionCommandRequiresRuntimeFlag(t *testing.T) {
	cmd := newAttachSessionCmd()
	cmd.SetArgs([]string{"sid-1"})

	err := cmd.Execute()
	if err == nil {
		t.Fatal("expected missing runtime flag error")
	}
	if !strings.Contains(err.Error(), `required flag(s) "runtime" not set`) {
		t.Fatalf("error = %v, want required runtime flag message", err)
	}
}

func TestAttachSessionCommandRejectsRemovedOverrideFlags(t *testing.T) {
	cmd := newAttachSessionCmd()
	cmd.SetArgs([]string{"sid-1", "--runtime", "codex", "--cwd", "/tmp/project"})

	err := cmd.Execute()
	if err == nil {
		t.Fatal("expected unknown flag error")
	}
	if !strings.Contains(err.Error(), "unknown flag: --cwd") {
		t.Fatalf("error = %v, want unknown --cwd flag message", err)
	}
}
