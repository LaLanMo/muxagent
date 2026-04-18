package daemon

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/LaLanMo/muxagent/cli/internal/appwire"
	"github.com/LaLanMo/muxagent/cli/internal/auth"
	"github.com/LaLanMo/muxagent/cli/internal/config"
	"github.com/LaLanMo/muxagent/cli/internal/control"
	"github.com/LaLanMo/muxagent/cli/internal/crypto"
	"github.com/LaLanMo/muxagent/cli/internal/domain"
	"github.com/LaLanMo/muxagent/cli/internal/keyring"
	"github.com/LaLanMo/muxagent/cli/internal/relayws"
	runtimemanager "github.com/LaLanMo/muxagent/cli/internal/runtime/manager"
	"github.com/LaLanMo/muxagent/cli/internal/sessionattach"
	"github.com/LaLanMo/muxagent/cli/internal/worktree"
)

const (
	relayReplayEventLimit = 4096
	relayReplayByteBudget = 2 * 1024 * 1024
)

var (
	errAttachSessionRuntimeRequired = errors.New("missing runtime")
	errAttachSessionIDRequired      = errors.New("missing session id")
)

type Daemon struct {
	control         *control.Server
	addr            string
	token           string
	relay           *relayws.Client
	relayURL        string
	rt              *runtimemanager.Manager
	eventBuf        *relayws.EventBuffer
	attachResolvers *sessionattach.Registry
	attachPublisher attachSessionPublisher
	stopOnce        sync.Once
	stopErr         error
	done            chan struct{}
}

type attachSessionPublisher interface {
	SendLiveEvent(event appwire.Event) error
	MachineID() string
}

func New(relayURL string) *Daemon {
	return &Daemon{
		relayURL:        relayURL,
		attachResolvers: sessionattach.NewRegistry(),
		done:            make(chan struct{}),
	}
}

func (d *Daemon) Start() error {
	token, err := randomToken()
	if err != nil {
		return err
	}
	d.token = token

	// Initialize runtime manager
	cfg, err := config.LoadEffective()
	if err != nil {
		return fmt.Errorf("failed to load config: %w", err)
	}
	d.rt = runtimemanager.New(cfg)
	d.eventBuf = relayws.NewEventBufferWithByteBudget(
		relayReplayEventLimit,
		relayReplayByteBudget,
	)

	mux := http.NewServeMux()

	// HTTP endpoints for daemon control only
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		control.WriteJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	mux.HandleFunc("/stop", func(w http.ResponseWriter, r *http.Request) {
		control.WriteJSON(w, http.StatusOK, map[string]string{"status": "stopping"})
		go func() {
			_ = d.Stop(context.Background())
		}()
	})
	mux.HandleFunc("/echo", func(w http.ResponseWriter, r *http.Request) {
		var payload struct {
			Message string `json:"message"`
		}
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			control.WriteJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
			return
		}
		if payload.Message == "" {
			payload.Message = "echo from daemon"
		}
		if d.relay == nil {
			control.WriteJSON(w, http.StatusBadRequest, map[string]string{"error": "relay not connected"})
			return
		}
		if err := d.relay.SendEcho(map[string]any{
			"from":    "daemon",
			"message": payload.Message,
			"ts":      time.Now().Unix(),
		}); err != nil {
			control.WriteJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
			return
		}
		control.WriteOK(w)
	})
	mux.HandleFunc("/remote/attach-session", d.handleAttachSession)

	server := control.NewServer(token, control.WithAuth(token, mux))
	addr, err := server.Listen()
	if err != nil {
		return err
	}
	d.control = server
	d.addr = addr

	// Connect to relay server
	hostname, _ := os.Hostname()

	creds, machineSignPriv, _, err := auth.LoadCredentials()
	if err != nil {
		return fmt.Errorf("failed to load credentials (run 'muxagent auth login' first): %w", err)
	}

	machineSignPub, err := creds.GetMachineSignPublicKey()
	if err != nil {
		return fmt.Errorf("failed to decode machine sign public key: %w", err)
	}
	fingerprint := crypto.HashKeyFingerprint(machineSignPub)
	accessToken := crypto.BuildMachineAccessToken(creds.MasterID, creds.MachineID, fingerprint, machineSignPriv, 5*time.Minute)

	keyringMgr := keyring.NewManager(creds.Keyring)
	relayHTTPURL := relayws.HTTPURLFromWS(d.relayURL)
	if err := keyringMgr.Sync(context.Background(), relayHTTPURL, accessToken); err != nil {
		return fmt.Errorf("failed to sync keyring: %w", err)
	}

	home, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("failed to get home dir: %w", err)
	}
	wtStore := worktree.NewStore(filepath.Join(home, ".muxagent", "worktrees.json"))
	if err := wtStore.Load(); err != nil {
		return fmt.Errorf("failed to load worktree store: %w", err)
	}

	relayClient, err := relayws.NewMachineClient(d.relayURL, hostname, creds, machineSignPriv, keyringMgr, d.rt, d.eventBuf, wtStore)
	if err != nil {
		return fmt.Errorf("failed to create relay client: %w", err)
	}

	// Start event bridge: runtime events → ring buffer → relay (to mobile)
	go d.runEventBridge(context.Background(), relayClient)

	go func() {
		backoff := time.Second
		const maxBackoff = 30 * time.Second
		for {
			if err := relayClient.Connect(context.Background()); err != nil {
				log.Printf("Relay connect failed: %v (retry in %v)", err, backoff)
				time.Sleep(backoff)
				backoff = min(backoff*2, maxBackoff)
				continue
			}
			backoff = time.Second // reset on successful connect

			if err := relayClient.Run(context.Background()); err != nil {
				log.Printf("Relay connection lost: %v (reconnecting...)", err)
			}
		}
	}()

	d.relay = relayClient
	d.attachPublisher = relayClient
	return nil
}

// runEventBridge reads events from the ACP runtime and hands them to the relay,
// which owns status tracking, buffering, and best-effort WS delivery.
func (d *Daemon) runEventBridge(ctx context.Context, relay *relayws.Client) {
	events := d.rt.Events()
	for {
		select {
		case <-ctx.Done():
			return
		case ev, ok := <-events:
			if !ok {
				return
			}
			if err := relay.SendEvent(ev); err != nil &&
				!errors.Is(err, relayws.ErrRelayNotConnected) &&
				!errors.Is(err, relayws.ErrNoActiveSession) &&
				!errors.Is(err, relayws.ErrStaleRelaySession) {
				log.Printf("event forward error: %v", err)
			}
		}
	}
}

func (d *Daemon) Stop(ctx context.Context) error {
	if ctx == nil {
		ctx = context.Background()
	}

	d.stopOnce.Do(func() {
		if d.rt != nil {
			d.rt.Stop()
		}
		if d.relay != nil {
			d.relay.Close()
		}
		if d.control != nil {
			shutdownCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
			defer cancel()
			d.stopErr = d.control.Shutdown(shutdownCtx)
		}
		close(d.done)
	})

	return d.stopErr
}

func (d *Daemon) handleAttachSession(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		control.WriteJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	var req control.AttachSessionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		control.WriteJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}

	resp, err := d.attachSession(r.Context(), req)
	if err != nil {
		status := http.StatusInternalServerError
		switch {
		case errors.Is(err, errAttachSessionRuntimeRequired),
			errors.Is(err, errAttachSessionIDRequired):
			status = http.StatusBadRequest
		case errors.Is(err, sessionattach.ErrSessionNotFound):
			status = http.StatusNotFound
		case errors.Is(err, sessionattach.ErrMissingCWD):
			status = http.StatusUnprocessableEntity
		case errors.Is(err, sessionattach.ErrUnsupportedRuntime):
			status = http.StatusNotImplemented
		case errors.Is(err, relayws.ErrRelayNotConnected):
			status = http.StatusServiceUnavailable
		case errors.Is(err, relayws.ErrNoActiveSession):
			status = http.StatusConflict
		}
		control.WriteJSON(w, status, map[string]string{"error": err.Error()})
		return
	}

	control.WriteJSON(w, http.StatusOK, resp)
}

func (d *Daemon) attachSession(
	ctx context.Context,
	req control.AttachSessionRequest,
) (control.AttachSessionResponse, error) {
	runtimeID := strings.TrimSpace(req.Runtime)
	if runtimeID == "" {
		return control.AttachSessionResponse{}, errAttachSessionRuntimeRequired
	}
	sessionID := strings.TrimSpace(req.SessionID)
	if sessionID == "" {
		return control.AttachSessionResponse{}, errAttachSessionIDRequired
	}

	resolvers := d.attachResolvers
	if resolvers == nil {
		resolvers = sessionattach.NewRegistry()
	}
	meta, err := resolvers.Resolve(runtimeID, sessionID)
	if err != nil {
		return control.AttachSessionResponse{}, err
	}
	if overrideCWD := strings.TrimSpace(req.CWD); overrideCWD != "" {
		meta.CWD = overrideCWD
	}
	if overrideTitle := strings.TrimSpace(req.Title); overrideTitle != "" {
		meta.Title = overrideTitle
	}
	if strings.TrimSpace(meta.CWD) == "" {
		return control.AttachSessionResponse{}, sessionattach.ErrMissingCWD
	}

	updatedAt := meta.UpdatedAt
	if updatedAt.IsZero() {
		updatedAt = time.Now().UTC()
	}
	createdAt := meta.CreatedAt
	if createdAt.IsZero() {
		createdAt = updatedAt
	}

	resp := control.AttachSessionResponse{
		OK:        true,
		SessionID: sessionID,
		Runtime:   runtimeID,
		CWD:       meta.CWD,
		Title:     meta.Title,
		Status:    string(domain.SessionStatusIdle),
		CreatedAt: createdAt,
		UpdatedAt: updatedAt,
	}
	if err := d.publishAttachedSessionStatus(ctx, resp); err != nil {
		return control.AttachSessionResponse{}, err
	}
	resp.Broadcasted = true
	return resp, nil
}

func (d *Daemon) publishAttachedSessionStatus(_ context.Context, resp control.AttachSessionResponse) error {
	if d.attachPublisher == nil {
		return relayws.ErrRelayNotConnected
	}
	machineID := strings.TrimSpace(d.attachPublisher.MachineID())
	return d.attachPublisher.SendLiveEvent(appwire.Event{
		Type:      appwire.EventSessionStatus,
		SessionID: resp.SessionID,
		At:        time.Now().UTC(),
		SessionInfo: &appwire.SessionStatusEvent{
			App: appwire.SessionStatusEventApp{
				ID:        resp.SessionID,
				Title:     resp.Title,
				Status:    appwire.SessionStatus(resp.Status),
				MachineID: machineID,
				Runtime:   resp.Runtime,
				CWD:       resp.CWD,
				CreatedAt: resp.CreatedAt,
				UpdatedAt: resp.UpdatedAt,
			},
		},
	})
}

func (d *Daemon) Address() string {
	return d.addr
}

func (d *Daemon) Token() string {
	return d.token
}

func (d *Daemon) Done() <-chan struct{} {
	return d.done
}

func randomToken() (string, error) {
	payload := make([]byte, 32)
	if _, err := rand.Read(payload); err != nil {
		return "", fmt.Errorf("token: %w", err)
	}
	return base64.RawURLEncoding.EncodeToString(payload), nil
}
