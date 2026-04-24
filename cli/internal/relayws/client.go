package relayws

import (
	"context"
	"crypto/ed25519"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/LaLanMo/muxagent/cli/internal/agentchat"
	"github.com/LaLanMo/muxagent/cli/internal/appwire"
	"github.com/LaLanMo/muxagent/cli/internal/auth"
	"github.com/LaLanMo/muxagent/cli/internal/crypto"
	"github.com/LaLanMo/muxagent/cli/internal/domain"
	"github.com/LaLanMo/muxagent/cli/internal/keyring"
	"github.com/LaLanMo/muxagent/cli/internal/worktree"
	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"golang.org/x/crypto/curve25519"
)

const (
	pingInterval = 15 * time.Second
	pongTimeout  = 10 * time.Second
	writeWait    = 5 * time.Second
)

var (
	ErrRelayNotConnected = errors.New("relay not connected")
	ErrNoActiveSession   = errors.New("no active session")
	ErrStaleRelaySession = errors.New("stale relay session")
)

type RuntimeClient = agentchat.Runtime

type Client struct {
	relayURL  string
	machineID string
	hostname  string

	creds           *auth.Credentials
	machineSignPriv ed25519.PrivateKey
	keyring         *keyring.Manager

	// Any mutation of conn/session state that affects outbound write safety must
	// acquire writeMu before stateMu. Write helpers use the same ordering, then
	// release stateMu before the websocket write so readers are not blocked on
	// network I/O.
	stateMu   sync.RWMutex
	conn      *websocket.Conn
	connEpoch uint64
	writeMu   sync.Mutex

	session       *Session // installed session used for inbound decrypt/rpc handling
	activeSession *Session // outbound-eligible session after session-ack is written

	runtime  agentchat.Runtime
	chatMu   sync.Mutex
	chat     *agentchat.Service
	eventBuf *EventBuffer
	wtStore  *worktree.Store

	sessionCWDMu sync.RWMutex
	sessionCWD   map[string]string // sessionID → cwd

	statusMu      sync.RWMutex
	sessionStatus map[string]domain.SessionStatus // sessionID → daemon-tracked status
}

func NewMachineClient(
	relayURL, hostname string,
	creds *auth.Credentials,
	machineSignPriv ed25519.PrivateKey,
	keyringMgr *keyring.Manager,
	rt RuntimeClient,
	eventBuf *EventBuffer,
	wtStore *worktree.Store,
) (*Client, error) {
	c, err := NewMachineTransportClient(relayURL, hostname, creds, machineSignPriv, keyringMgr, rt, eventBuf, wtStore)
	if err != nil {
		return nil, err
	}
	c.SetAgentChat(agentchat.New(agentchat.Config{
		MachineID:            c.machineID,
		Runtime:              rt,
		EventBuffer:          eventBuf,
		WorktreeStore:        wtStore,
		Transport:            c,
		SessionCWD:           c.sessionCWD,
		SessionStatus:        c.sessionStatus,
		IgnoreTransportError: isExpectedRelayDrop,
	}))
	return c, nil
}

// NewMachineTransportClient creates only the relay transport adapter. Callers
// that own the agent chat service should inject it with SetAgentChat.
func NewMachineTransportClient(
	relayURL, hostname string,
	creds *auth.Credentials,
	machineSignPriv ed25519.PrivateKey,
	keyringMgr *keyring.Manager,
	rt RuntimeClient,
	eventBuf *EventBuffer,
	wtStore *worktree.Store,
) (*Client, error) {
	if creds == nil {
		return nil, fmt.Errorf("credentials required")
	}
	if machineSignPriv == nil {
		return nil, fmt.Errorf("machine signing private key required")
	}
	if keyringMgr == nil {
		return nil, fmt.Errorf("keyring required")
	}
	c := &Client{
		relayURL:        relayURL,
		machineID:       creds.MachineID,
		hostname:        hostname,
		creds:           creds,
		machineSignPriv: machineSignPriv,
		keyring:         keyringMgr,
		runtime:         rt,
		eventBuf:        eventBuf,
		wtStore:         wtStore,
		sessionCWD:      make(map[string]string),
		sessionStatus:   make(map[string]domain.SessionStatus),
	}
	return c, nil
}

func (c *Client) HasSession() bool {
	c.stateMu.RLock()
	defer c.stateMu.RUnlock()
	return c.session != nil || c.activeSession != nil
}

func (c *Client) MachineID() string {
	return c.machineID
}

func (c *Client) agentChat() *agentchat.Service {
	c.chatMu.Lock()
	defer c.chatMu.Unlock()
	if c.chat != nil {
		return c.chat
	}
	if c.sessionCWD == nil {
		c.sessionCWD = make(map[string]string)
	}
	if c.sessionStatus == nil {
		c.sessionStatus = make(map[string]domain.SessionStatus)
	}
	c.chat = agentchat.New(agentchat.Config{
		MachineID:            c.machineID,
		Runtime:              c.runtime,
		EventBuffer:          c.eventBuf,
		WorktreeStore:        c.wtStore,
		Transport:            c,
		SessionCWD:           c.sessionCWD,
		SessionStatus:        c.sessionStatus,
		IgnoreTransportError: isExpectedRelayDrop,
	})
	return c.chat
}

func (c *Client) SetAgentChat(service *agentchat.Service) {
	c.chatMu.Lock()
	defer c.chatMu.Unlock()
	c.chat = service
}

func (c *Client) Connect(ctx context.Context) error {
	oldConn := c.detachActiveConnection()
	if oldConn != nil {
		_ = c.closeConn(oldConn)
	}

	conn, _, err := websocket.DefaultDialer.DialContext(ctx, c.relayURL, nil)
	if err != nil {
		return fmt.Errorf("dial relay: %w", err)
	}

	watcherDone := make(chan struct{})
	var watcherStopOnce sync.Once
	stopWatcher := func() {
		watcherStopOnce.Do(func() {
			close(watcherDone)
		})
	}
	defer stopWatcher()
	go func() {
		select {
		case <-ctx.Done():
			_ = conn.Close()
		case <-watcherDone:
		}
	}()

	if err := writeJSONTo(conn, RegisterMessage{
		Type:      MessageTypeRegister,
		Role:      RoleMachine,
		MachineID: c.machineID,
		Hostname:  c.hostname,
	}); err != nil {
		_ = conn.Close()
		return fmt.Errorf("send register: %w", err)
	}

	for {
		var raw json.RawMessage
		if err := conn.ReadJSON(&raw); err != nil {
			conn.Close()
			return fmt.Errorf("read register response: %w", err)
		}
		var envelope MessageEnvelope
		if err := json.Unmarshal(raw, &envelope); err != nil {
			continue
		}
		switch envelope.Type {
		case MessageTypeChallenge:
			var msg ChallengeMessage
			if err := json.Unmarshal(raw, &msg); err != nil || msg.Nonce == "" {
				_ = conn.Close()
				return fmt.Errorf("invalid challenge from relay")
			}
			signedMessage := crypto.BuildMachineAuthMessage(c.machineID, msg.Nonce)
			signature := crypto.SignBase64(signedMessage, c.machineSignPriv)
			if err := writeJSONTo(conn, ChallengeResponseMessage{
				Type:      MessageTypeChallengeResponse,
				Signature: signature,
			}); err != nil {
				_ = conn.Close()
				return fmt.Errorf("send challenge response: %w", err)
			}
		case MessageTypeRegistered:
			// Relay sends pings; we reply with pongs and reset the read deadline.
			// Overriding the default ping handler means we must send the pong ourselves.
			conn.SetPingHandler(func(appData string) error {
				_ = conn.SetReadDeadline(time.Now().Add(pingInterval + pongTimeout))
				return conn.WriteControl(websocket.PongMessage, []byte(appData), time.Now().Add(writeWait))
			})
			_ = conn.SetReadDeadline(time.Now().Add(pingInterval + pongTimeout))
			stopWatcher()
			if err := ctx.Err(); err != nil {
				_ = conn.Close()
				return err
			}
			c.publishActiveConnection(conn)
			return nil
		case MessageTypeError:
			var msg ErrorMessage
			if err := json.Unmarshal(raw, &msg); err != nil {
				_ = conn.Close()
				return fmt.Errorf("registration failed: unknown error")
			}
			_ = conn.Close()
			return fmt.Errorf("registration failed: %s", msg.Error)
		}
	}
}

func (c *Client) Run(ctx context.Context) error {
	conn, connEpoch := c.currentConnection()
	if conn == nil {
		return ErrRelayNotConnected
	}

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}

		var raw json.RawMessage
		if err := conn.ReadJSON(&raw); err != nil {
			return fmt.Errorf("read message: %w", err)
		}

		var envelope MessageEnvelope
		if err := json.Unmarshal(raw, &envelope); err != nil {
			continue
		}

		switch envelope.Type {
		case MessageTypeSessionInit:
			var msg SessionInitMessage
			if err := json.Unmarshal(raw, &msg); err != nil {
				continue
			}
			if err := c.handleSessionInit(connEpoch, msg); err != nil && !isExpectedRelayDrop(err) {
				log.Printf("session-init error: %v", err)
			}
		case MessageTypeSessionEnd:
			var msg SessionEndMessage
			if err := json.Unmarshal(raw, &msg); err != nil {
				continue
			}
			c.handleSessionEnd(connEpoch, msg)
		case MessageTypeRPC:
			var enc EncryptedMessage
			if err := json.Unmarshal(raw, &enc); err != nil {
				continue
			}
			// RPCs like session.prompt can block for a long time while the agent runs.
			// Handle them off the read loop so follow-up requests like session.cancel
			// and session.load are still processed promptly.
			go c.handleRPC(connEpoch, enc)
		case MessageTypeResponse:
			var enc EncryptedMessage
			if err := json.Unmarshal(raw, &enc); err != nil {
				continue
			}
			c.handleResponse(enc)
		case MessageTypeEvent:
			continue
		case MessageTypeError:
			var msg ErrorMessage
			if err := json.Unmarshal(raw, &msg); err == nil {
				log.Printf("relay error: %s", msg.Error)
			}
		}
	}
}

func (c *Client) handleSessionInit(connEpoch uint64, msg SessionInitMessage) error {
	if msg.MachineID != c.machineID {
		return fmt.Errorf("machine_id mismatch")
	}
	claims, err := c.keyring.VerifyMachineToken(msg.MachineToken)
	if err != nil {
		return err
	}
	if claims.MachineID != c.machineID || claims.MasterID != c.creds.MasterID {
		return fmt.Errorf("machine token mismatch")
	}
	pub, ok := c.keyring.SignPub(claims.Fingerprint)
	if !ok {
		return fmt.Errorf("unauthorized signer")
	}
	sigBytes, err := base64.StdEncoding.DecodeString(msg.Signature)
	if err != nil {
		return err
	}
	initMsg := crypto.BuildSessionInitMessage(c.machineID, msg.ClientEphemeralPub)
	if !crypto.Verify(pub, []byte(initMsg), sigBytes) {
		return fmt.Errorf("invalid session-init signature")
	}

	clientEphemeralPub, err := base64.StdEncoding.DecodeString(msg.ClientEphemeralPub)
	if err != nil || len(clientEphemeralPub) != 32 {
		return fmt.Errorf("invalid client_ephemeral_pub")
	}

	machineEphemeralPub, machineEphemeralPriv, err := crypto.GenerateX25519KeyPair()
	if err != nil {
		return err
	}
	sharedSecret, err := curve25519.X25519(machineEphemeralPriv[:], clientEphemeralPub)
	if err != nil {
		return err
	}
	machineEphemeralPubB64 := base64.StdEncoding.EncodeToString(machineEphemeralPub[:])
	transcript := msg.ClientEphemeralPub + "|" + machineEphemeralPubB64 + "|" + c.machineID
	key, err := deriveSessionKey(sharedSecret, transcript)
	if err != nil {
		return err
	}

	session := newSession(c.machineID, key, connEpoch)
	if err := c.installSession(session); err != nil {
		return err
	}

	ackMsg := crypto.BuildSessionAckMessage(c.machineID, machineEphemeralPubB64)
	ackSig := crypto.SignBase64(ackMsg, c.machineSignPriv)
	if err := c.writeSessionAckAndActivate(session, SessionAckMessage{
		Type:                MessageTypeSessionAck,
		MachineID:           c.machineID,
		MachineEphemeralPub: machineEphemeralPubB64,
		Signature:           ackSig,
	}); err != nil {
		return err
	}
	return nil
}

// --- RPC routing ---

func (c *Client) handleRPC(connEpoch uint64, enc EncryptedMessage) {
	session := c.currentSession()
	if session == nil || session.connEpoch != connEpoch {
		return
	}
	plaintext, err := session.decrypt(string(enc.Type), enc.MsgID, enc.Nonce, enc.Ciphertext)
	if err != nil {
		return
	}
	var payload appwire.RPCRequest
	if err := json.Unmarshal(plaintext, &payload); err != nil {
		return
	}

	ctx := context.Background()
	var result any
	var respErr string

	if payload.Method == "echo" {
		params, err := appwire.DecodeEchoParams(payload.Params)
		if err != nil {
			respErr = "invalid echo params: " + err.Error()
		} else {
			log.Printf("echo request from client: %v", params)
			result = params
		}
	} else {
		result, respErr = c.agentChat().HandleRPC(ctx, payload)
	}

	respBytes, err := appwire.MarshalRPCResponse(result, respErr)
	if err != nil {
		log.Printf("rpc marshal response: %v", err)
		return
	}
	nonce, ciphertext, err := session.encrypt(string(MessageTypeResponse), enc.MsgID, respBytes)
	if err != nil {
		log.Printf("rpc encrypt response: %v", err)
		return
	}
	if err := c.writeForSession(session, EncryptedMessage{
		Type:       MessageTypeResponse,
		MachineID:  c.machineID,
		MsgID:      enc.MsgID,
		Nonce:      nonce,
		Ciphertext: ciphertext,
	}); err != nil && !isExpectedRelayDrop(err) {
		log.Printf("rpc write response: %v", err)
	}
}

func (c *Client) rpcRuntimeList(ctx context.Context) (any, string) {
	return c.agentChat().RuntimeList(ctx)
}

func (c *Client) rpcCreateSession(ctx context.Context, params appwire.CreateSessionParams) (any, string) {
	return c.agentChat().CreateSession(ctx, params)
}

func (c *Client) rpcLoadSession(ctx context.Context, params appwire.LoadSessionParams) (any, string) {
	return c.agentChat().LoadSession(ctx, params)
}

func (c *Client) rpcAttachSession(ctx context.Context, params appwire.AttachSessionParams) (any, string) {
	return c.agentChat().AttachSession(ctx, params)
}

func (c *Client) rpcResolveSessions(ctx context.Context, params appwire.ResolveSessionsParams) (any, string) {
	return c.agentChat().ResolveSessions(ctx, params)
}

func (c *Client) resolveRequestedRuntime(runtimeID string) string {
	return c.agentChat().ResolveRequestedRuntime(runtimeID)
}

func (c *Client) rpcPrompt(ctx context.Context, params appwire.PromptParams) (any, string) {
	return c.agentChat().Prompt(ctx, params)
}

func (c *Client) rpcCancel(ctx context.Context, params appwire.CancelParams) (any, string) {
	return c.agentChat().Cancel(ctx, params)
}

func (c *Client) rpcSetMode(ctx context.Context, params appwire.SetModeParams) (any, string) {
	return c.agentChat().SetMode(ctx, params)
}

func (c *Client) rpcSetConfigOption(ctx context.Context, params appwire.SetConfigOptionParams) (any, string) {
	return c.agentChat().SetConfigOption(ctx, params)
}

func (c *Client) rpcReplyPermission(ctx context.Context, params appwire.ReplyPermissionParams) (any, string) {
	return c.agentChat().ReplyPermission(ctx, params)
}

func (c *Client) rpcPendingApprovals(ctx context.Context) (any, string) {
	return c.agentChat().PendingApprovals(ctx)
}

func (c *Client) rpcResyncEvents(ctx context.Context, params appwire.ResyncEventsParams) (any, string) {
	return c.agentChat().ResyncEvents(ctx, params)
}

func (c *Client) rpcResyncEventsPage(ctx context.Context, params appwire.ResyncEventsPageParams) (any, string) {
	return c.agentChat().ResyncEventsPage(ctx, params)
}

func (c *Client) rpcReplayHead(ctx context.Context) (any, string) {
	return c.agentChat().ReplayHead(ctx)
}

func (c *Client) rpcFsSearch(ctx context.Context, params appwire.FsSearchParams) (any, string) {
	return c.agentChat().FsSearch(ctx, params)
}

func (c *Client) rpcFsList(ctx context.Context, params appwire.FsListParams) (any, string) {
	return c.agentChat().FsList(ctx, params)
}

// --- Event forwarding ---

// SendEvent tracks, buffers, and sends an app transport event.
func (c *Client) SendEvent(event appwire.Event) error {
	return c.agentChat().SendEvent(event)
}

func (c *Client) DeliverEvent(event appwire.Event) error {
	return c.deliverEvent(event, true)
}

func (c *Client) DeliverLiveEvent(event appwire.Event) error {
	return c.deliverEvent(event, false)
}

// deliverEvent encrypts an already-normalized app transport event and sends it
// to the connected client via WS.
func (c *Client) deliverEvent(event appwire.Event, includeHints bool) error {
	msgID := uuid.New().String()
	body, err := marshalEvent(event)
	if err != nil {
		return err
	}
	return c.writeEncryptedForActiveSession(func(session *Session) (EncryptedMessage, error) {
		nonce, ciphertext, err := session.encrypt(string(MessageTypeEvent), msgID, body)
		if err != nil {
			return EncryptedMessage{}, err
		}
		msg := EncryptedMessage{
			Type:       MessageTypeEvent,
			MachineID:  c.machineID,
			MsgID:      msgID,
			Nonce:      nonce,
			Ciphertext: ciphertext,
		}
		if includeHints {
			switch event.Type {
			case appwire.EventApprovalRequested, appwire.EventRunFailed, appwire.EventRunFinished:
				msg.Hint = &EventHint{Event: string(event.Type)}
			}
		}
		return msg, nil
	})
}

// SendLiveEvent writes an event only to the current active phone session.
// Unlike SendEvent, it does not enter the replay buffer when delivery fails.
func (c *Client) SendLiveEvent(event appwire.Event) error {
	return c.agentChat().SendLiveEvent(event)
}

func (c *Client) setSessionStatus(sessionID string, status domain.SessionStatus) {
	c.agentChat().SetSessionStatus(sessionID, status)
}

func (c *Client) ensureSessionStatus(sessionID string, status domain.SessionStatus) {
	c.agentChat().EnsureSessionStatus(sessionID, status)
}

func (c *Client) resolvedSessionStatus(sessionID string) domain.SessionStatus {
	return c.agentChat().ResolvedSessionStatus(sessionID)
}

func (c *Client) clearSessionStatus(sessionID string) {
	c.agentChat().ClearSessionStatus(sessionID)
}

func (c *Client) setSessionCWD(sessionID, cwd string) {
	c.agentChat().SetSessionCWD(sessionID, cwd)
}

func (c *Client) sessionCWDFor(sessionID string) (string, bool) {
	return c.agentChat().SessionCWD(sessionID)
}

func (c *Client) eventBuffer() *EventBuffer {
	return c.agentChat().EventBuffer()
}

func (c *Client) worktreeStore() *worktree.Store {
	return c.agentChat().WorktreeStore()
}

// --- Response handling ---

func (c *Client) handleResponse(enc EncryptedMessage) {
	session := c.currentSession()
	if session == nil {
		return
	}
	plaintext, err := session.decrypt(string(enc.Type), enc.MsgID, enc.Nonce, enc.Ciphertext)
	if err != nil {
		return
	}
	var payload map[string]any
	if err := json.Unmarshal(plaintext, &payload); err != nil {
		return
	}
	log.Printf("response from client: %v", payload)
}

func (c *Client) handleSessionEnd(connEpoch uint64, msg SessionEndMessage) {
	if msg.MachineID == "" || msg.MachineID != c.machineID {
		return
	}
	c.lockWriteState()
	defer c.unlockWriteState()

	if c.connEpoch != connEpoch {
		return
	}
	c.session = nil
	c.activeSession = nil
	log.Printf("session ended by client")
}

// SendEcho sends an echo RPC (kept for backward compatibility).
func (c *Client) SendEcho(params map[string]any) error {
	msgID := uuid.New().String()
	body, err := appwire.MarshalRPCRequest("echo", params)
	if err != nil {
		return err
	}
	return c.writeEncryptedForActiveSession(func(session *Session) (EncryptedMessage, error) {
		nonce, ciphertext, err := session.encrypt(string(MessageTypeRPC), msgID, body)
		if err != nil {
			return EncryptedMessage{}, err
		}
		return EncryptedMessage{
			Type:       MessageTypeRPC,
			MachineID:  c.machineID,
			MsgID:      msgID,
			Nonce:      nonce,
			Ciphertext: ciphertext,
		}, nil
	})
}

func (c *Client) Close() error {
	oldConn := c.detachActiveConnection()
	if oldConn == nil {
		return nil
	}
	return c.closeConn(oldConn)
}

func (c *Client) currentConnection() (*websocket.Conn, uint64) {
	c.stateMu.RLock()
	defer c.stateMu.RUnlock()
	return c.conn, c.connEpoch
}

func (c *Client) currentSession() *Session {
	c.stateMu.RLock()
	defer c.stateMu.RUnlock()
	return c.session
}

func (c *Client) currentActiveSession() *Session {
	c.stateMu.RLock()
	defer c.stateMu.RUnlock()
	return c.activeSession
}

func (c *Client) lockWriteState() {
	c.writeMu.Lock()
	c.stateMu.Lock()
}

func (c *Client) unlockWriteState() {
	c.stateMu.Unlock()
	c.writeMu.Unlock()
}

func (c *Client) detachActiveConnection() *websocket.Conn {
	c.lockWriteState()
	defer c.unlockWriteState()
	return c.detachActiveConnectionLocked()
}

func (c *Client) detachActiveConnectionLocked() *websocket.Conn {
	oldConn := c.conn
	c.conn = nil
	c.session = nil
	c.activeSession = nil
	c.connEpoch++
	return oldConn
}

func (c *Client) publishActiveConnection(conn *websocket.Conn) uint64 {
	c.lockWriteState()
	defer c.unlockWriteState()
	return c.publishActiveConnectionLocked(conn)
}

func (c *Client) publishActiveConnectionLocked(conn *websocket.Conn) uint64 {
	c.connEpoch++
	c.conn = conn
	c.session = nil
	c.activeSession = nil
	return c.connEpoch
}

func (c *Client) installSession(session *Session) error {
	if session == nil {
		return ErrNoActiveSession
	}

	c.stateMu.Lock()
	defer c.stateMu.Unlock()

	if c.connEpoch != session.connEpoch {
		return ErrStaleRelaySession
	}
	if c.conn == nil {
		return ErrRelayNotConnected
	}

	c.session = session
	c.activeSession = nil
	return nil
}

func (c *Client) activateSession(session *Session) error {
	if session == nil {
		return ErrNoActiveSession
	}

	c.stateMu.Lock()
	defer c.stateMu.Unlock()

	if c.connEpoch != session.connEpoch {
		return ErrStaleRelaySession
	}
	if c.conn == nil {
		return ErrRelayNotConnected
	}
	if c.session != session {
		return ErrStaleRelaySession
	}

	c.activeSession = session
	return nil
}

func (c *Client) clearSession(session *Session) {
	if session == nil {
		return
	}

	c.lockWriteState()
	defer c.unlockWriteState()
	c.clearSessionLocked(session)
}

func (c *Client) clearSessionLocked(session *Session) {
	if c.session == session {
		c.session = nil
	}
	if c.activeSession == session {
		c.activeSession = nil
	}
}

func (c *Client) writeSessionAckAndActivate(session *Session, ack SessionAckMessage) error {
	if session == nil {
		return ErrNoActiveSession
	}

	c.writeMu.Lock()
	defer c.writeMu.Unlock()

	c.stateMu.RLock()
	currentEpoch := c.connEpoch
	conn := c.conn
	c.stateMu.RUnlock()
	if currentEpoch != session.connEpoch {
		return ErrStaleRelaySession
	}
	if conn == nil {
		return ErrRelayNotConnected
	}
	if err := writeJSONTo(conn, ack); err != nil {
		c.stateMu.Lock()
		c.clearSessionLocked(session)
		c.stateMu.Unlock()
		return err
	}

	c.stateMu.Lock()
	defer c.stateMu.Unlock()
	if c.connEpoch != session.connEpoch {
		c.clearSessionLocked(session)
		return ErrStaleRelaySession
	}
	if c.conn != conn {
		c.clearSessionLocked(session)
		return ErrStaleRelaySession
	}
	if c.session != session {
		return ErrStaleRelaySession
	}
	c.activeSession = session
	return nil
}

func (c *Client) writeEncryptedForActiveSession(build func(session *Session) (EncryptedMessage, error)) error {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()

	c.stateMu.RLock()
	currentEpoch := c.connEpoch
	conn := c.conn
	session := c.activeSession
	c.stateMu.RUnlock()
	if conn == nil {
		return ErrRelayNotConnected
	}
	if session == nil {
		return ErrNoActiveSession
	}

	msg, err := build(session)
	if err != nil {
		return err
	}

	c.stateMu.RLock()
	currentConn := c.conn
	currentSession := c.activeSession
	currentEpochNow := c.connEpoch
	c.stateMu.RUnlock()
	if currentEpochNow != currentEpoch {
		return ErrStaleRelaySession
	}
	if currentConn == nil {
		return ErrRelayNotConnected
	}
	if currentConn != conn {
		return ErrStaleRelaySession
	}
	if currentSession == nil {
		return ErrNoActiveSession
	}
	if currentSession != session {
		return ErrStaleRelaySession
	}

	return writeJSONTo(conn, msg)
}

func (c *Client) writeProtocolForEpoch(epoch uint64, v any) error {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()

	c.stateMu.RLock()
	currentEpoch := c.connEpoch
	conn := c.conn
	c.stateMu.RUnlock()
	if currentEpoch != epoch {
		return ErrStaleRelaySession
	}
	if conn == nil {
		return ErrRelayNotConnected
	}
	return writeJSONTo(conn, v)
}

func (c *Client) writeForSession(session *Session, v any) error {
	if session == nil {
		return ErrNoActiveSession
	}

	c.writeMu.Lock()
	defer c.writeMu.Unlock()

	c.stateMu.RLock()
	currentEpoch := c.connEpoch
	conn := c.conn
	currentSession := c.activeSession
	c.stateMu.RUnlock()
	if currentEpoch != session.connEpoch {
		return ErrStaleRelaySession
	}
	if conn == nil {
		return ErrRelayNotConnected
	}
	if currentSession == nil {
		return ErrNoActiveSession
	}
	if currentSession != session {
		return ErrStaleRelaySession
	}

	return writeJSONTo(conn, v)
}

func (c *Client) closeConn(conn *websocket.Conn) error {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	return conn.Close()
}

func writeJSONTo(conn *websocket.Conn, v any) error {
	return conn.WriteJSON(v)
}

func isExpectedRelayDrop(err error) bool {
	return errors.Is(err, ErrRelayNotConnected) ||
		errors.Is(err, ErrNoActiveSession) ||
		errors.Is(err, ErrStaleRelaySession)
}
