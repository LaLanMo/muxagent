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
	"sync"
	"time"

	"github.com/LaLanMo/muxagent/cli/internal/agentchat"
	"github.com/LaLanMo/muxagent/cli/internal/auth"
	"github.com/LaLanMo/muxagent/cli/internal/config"
	"github.com/LaLanMo/muxagent/cli/internal/control"
	"github.com/LaLanMo/muxagent/cli/internal/crypto"
	"github.com/LaLanMo/muxagent/cli/internal/keyring"
	"github.com/LaLanMo/muxagent/cli/internal/relayws"
	runtimemanager "github.com/LaLanMo/muxagent/cli/internal/runtime/manager"
	"github.com/LaLanMo/muxagent/cli/internal/sessionattach"
	"github.com/LaLanMo/muxagent/cli/internal/worktree"
	"github.com/google/uuid"
)

const (
	relayReplayEventLimit = 4096
	relayReplayByteBudget = 2 * 1024 * 1024
)

type Daemon struct {
	control         *control.Server
	addr            string
	token           string
	instanceID      string
	relay           *relayws.Client
	relayURL        string
	rt              *runtimemanager.Manager
	chat            *agentchat.Service
	eventBuf        *agentchat.EventBuffer
	localEvents     *localEventBroker
	attachResolvers *sessionattach.Registry
	attachPublisher sessionattach.Publisher
	cancel          context.CancelFunc
	stopOnce        sync.Once
	stopErr         error
	done            chan struct{}
}

type relayAdapter struct {
	client       *relayws.Client
	keyring      *keyring.Manager
	relayHTTPURL string
	accessToken  string
}

func New(relayURL string) *Daemon {
	return &Daemon{
		relayURL:        relayURL,
		instanceID:      uuid.NewString(),
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
	daemonCtx, cancel := context.WithCancel(context.Background())
	d.cancel = cancel

	// Initialize runtime manager
	cfg, err := config.LoadEffective()
	if err != nil {
		cancel()
		return fmt.Errorf("failed to load config: %w", err)
	}
	d.rt = runtimemanager.New(cfg)
	d.eventBuf = agentchat.NewEventBufferWithByteBudget(
		relayReplayEventLimit,
		relayReplayByteBudget,
	)
	d.localEvents = newLocalEventBroker(d.eventBuf)

	home, err := os.UserHomeDir()
	if err != nil {
		cancel()
		return fmt.Errorf("failed to get home dir: %w", err)
	}
	wtStore := worktree.NewStore(filepath.Join(home, ".muxagent", "worktrees.json"))
	if err := wtStore.Load(); err != nil {
		cancel()
		return fmt.Errorf("failed to load worktree store: %w", err)
	}

	hostname, _ := os.Hostname()
	machineID, relayAdapter := d.configureRelayClient(hostname, wtStore)
	if machineID == "" {
		machineID, err = localMachineID()
		if err != nil {
			cancel()
			return fmt.Errorf("failed to resolve local machine id: %w", err)
		}
	}

	transport := &localAgentChatTransport{
		local: d.localEvents,
	}
	if relayAdapter != nil {
		transport.relay = relayAdapter.client
	}
	chatService := agentchat.New(agentchat.Config{
		MachineID:            machineID,
		Runtime:              d.rt,
		EventBuffer:          d.eventBuf,
		WorktreeStore:        wtStore,
		Transport:            transport,
		AttachRegistry:       d.attachResolvers,
		IgnoreTransportError: isExpectedRelayDrop,
	})
	if relayAdapter != nil {
		relayAdapter.client.SetAgentChat(chatService)
	}

	if relayAdapter != nil {
		d.relay = relayAdapter.client
	}
	d.chat = chatService
	d.attachPublisher = chatService

	mux := http.NewServeMux()

	// HTTP endpoints for daemon control only
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		control.WriteJSON(w, http.StatusOK, map[string]string{
			"status":      "ok",
			"instance_id": d.instanceID,
		})
	})
	mux.HandleFunc("/stop", func(w http.ResponseWriter, r *http.Request) {
		control.WriteJSON(w, http.StatusOK, map[string]string{"status": "stopping"})
		go func() {
			shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			_ = d.Stop(shutdownCtx)
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
	mux.HandleFunc("/agentchat/rpc", d.handleAgentChatRPC)
	mux.HandleFunc("/agentchat/events", d.handleAgentChatEvents)

	server := control.NewServer(token, control.WithAuth(token, mux))
	addr, err := server.Listen()
	if err != nil {
		cancel()
		return err
	}
	d.control = server
	d.addr = addr

	// Start event bridge: runtime events -> agentchat -> relay/local subscribers.
	go d.runEventBridge(daemonCtx, chatService)
	if relayAdapter != nil {
		go d.runRelayLoop(daemonCtx, relayAdapter)
	}
	return nil
}

func (d *Daemon) configureRelayClient(
	hostname string,
	wtStore *worktree.Store,
) (string, *relayAdapter) {
	creds, machineSignPriv, _, err := auth.LoadCredentials()
	if err != nil {
		log.Printf("Relay disabled: credentials unavailable: %v", err)
		return "", nil
	}
	machineID := creds.MachineID

	machineSignPub, err := creds.GetMachineSignPublicKey()
	if err != nil {
		log.Printf("Relay disabled: failed to decode machine sign public key: %v", err)
		return machineID, nil
	}
	fingerprint := crypto.HashKeyFingerprint(machineSignPub)
	accessToken := crypto.BuildMachineAccessToken(creds.MasterID, creds.MachineID, fingerprint, machineSignPriv, 5*time.Minute)

	keyringMgr := keyring.NewManager(creds.Keyring)
	relayHTTPURL := relayws.HTTPURLFromWS(d.relayURL)
	relayClient, err := relayws.NewMachineTransportClient(d.relayURL, hostname, creds, machineSignPriv, keyringMgr, d.rt, d.eventBuf, wtStore)
	if err != nil {
		log.Printf("Relay disabled: failed to create relay client: %v", err)
		return machineID, nil
	}
	return machineID, &relayAdapter{
		client:       relayClient,
		keyring:      keyringMgr,
		relayHTTPURL: relayHTTPURL,
		accessToken:  accessToken,
	}
}

func (d *Daemon) runRelayLoop(ctx context.Context, adapter *relayAdapter) {
	if adapter == nil || adapter.client == nil {
		return
	}
	backoff := time.Second
	const maxBackoff = 30 * time.Second
	for {
		if ctx.Err() != nil {
			return
		}
		d.syncRelayKeyring(ctx, adapter)
		if err := adapter.client.Connect(ctx); err != nil {
			if ctx.Err() != nil {
				return
			}
			log.Printf("Relay connect failed: %v (retry in %v)", err, backoff)
			if !sleepContext(ctx, backoff) {
				return
			}
			backoff = min(backoff*2, maxBackoff)
			continue
		}
		backoff = time.Second

		if err := adapter.client.Run(ctx); err != nil && ctx.Err() == nil {
			log.Printf("Relay connection lost: %v (reconnecting...)", err)
		}
	}
}

func (d *Daemon) syncRelayKeyring(ctx context.Context, adapter *relayAdapter) {
	if adapter == nil || adapter.keyring == nil {
		return
	}
	syncCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if err := adapter.keyring.Sync(syncCtx, adapter.relayHTTPURL, adapter.accessToken); err != nil && ctx.Err() == nil {
		log.Printf("Relay keyring sync failed: %v", err)
	}
}

func sleepContext(ctx context.Context, delay time.Duration) bool {
	timer := time.NewTimer(delay)
	defer timer.Stop()
	select {
	case <-timer.C:
		return true
	case <-ctx.Done():
		return false
	}
}

// runEventBridge reads events from the ACP runtime and hands them to agentchat,
// which owns status tracking, buffering, and best-effort transport delivery.
func (d *Daemon) runEventBridge(ctx context.Context, chat *agentchat.Service) {
	events := d.rt.Events()
	for {
		select {
		case <-ctx.Done():
			return
		case ev, ok := <-events:
			if !ok {
				return
			}
			if err := chat.SendEvent(ev); err != nil && !isExpectedRelayDrop(err) {
				log.Printf("event forward error: %v", err)
			}
		}
	}
}

func isExpectedRelayDrop(err error) bool {
	return errors.Is(err, relayws.ErrRelayNotConnected) ||
		errors.Is(err, relayws.ErrNoActiveSession) ||
		errors.Is(err, relayws.ErrStaleRelaySession)
}

func (d *Daemon) Stop(ctx context.Context) error {
	if ctx == nil {
		ctx = context.Background()
	}

	d.stopOnce.Do(func() {
		if d.cancel != nil {
			d.cancel()
		}
		if d.chat != nil {
			d.stopErr = d.chat.Close(ctx)
		}
		if d.rt != nil {
			d.rt.Stop()
		}
		if d.relay != nil {
			d.relay.Close()
		}
		if d.control != nil {
			shutdownCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
			defer cancel()
			if err := d.control.Shutdown(shutdownCtx); d.stopErr == nil && err != nil {
				d.stopErr = err
			}
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
		case errors.Is(err, sessionattach.ErrRuntimeRequired),
			errors.Is(err, sessionattach.ErrSessionIDRequired):
			status = http.StatusBadRequest
		case errors.Is(err, sessionattach.ErrSessionNotFound):
			status = http.StatusNotFound
		case errors.Is(err, sessionattach.ErrMissingCWD):
			status = http.StatusUnprocessableEntity
		case errors.Is(err, sessionattach.ErrUnsupportedRuntime):
			status = http.StatusNotImplemented
		case errors.Is(err, sessionattach.ErrPublisherRequired),
			errors.Is(err, relayws.ErrRelayNotConnected):
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
	result, err := sessionattach.Execute(
		ctx,
		d.attachResolvers,
		d.attachPublisher,
		sessionattach.Request{
			SessionID: req.SessionID,
			Runtime:   req.Runtime,
		},
	)
	if err != nil {
		return control.AttachSessionResponse{}, err
	}

	return control.AttachSessionResponse{
		OK:          true,
		SessionID:   result.SessionID,
		Runtime:     result.Runtime,
		CWD:         result.CWD,
		Title:       result.Title,
		Status:      string(result.Status),
		CreatedAt:   result.CreatedAt,
		UpdatedAt:   result.UpdatedAt,
		Broadcasted: true,
	}, nil
}

func (d *Daemon) Address() string {
	return d.addr
}

func (d *Daemon) Token() string {
	return d.token
}

func (d *Daemon) InstanceID() string {
	return d.instanceID
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
