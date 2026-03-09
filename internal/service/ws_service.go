package service

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"time"

	"github.com/LaLanMo/muxagent-relay/internal/infra/crypto"
	"github.com/LaLanMo/muxagent-relay/internal/repository"
	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"golang.org/x/time/rate"
)

const (
	pingInterval = 15 * time.Second
	pongTimeout  = 10 * time.Second
	writeWait    = 5 * time.Second
)

type WSService interface {
	HandleConnection(ctx context.Context, conn *websocket.Conn)
}

type WSServiceConfig struct {
	InboundBytesPerMin int64
	RegisterTimeout    time.Duration
}

type wsServiceImpl struct {
	machines     repository.MachineRepository
	masterKeys   repository.MasterKeyRepository
	tokenService TokenService
	hub          *WSHub
	sessions     *SessionRegistry
	pushService  PushService
	cfg          WSServiceConfig
}

func NewWSService(
	machines repository.MachineRepository,
	masterKeys repository.MasterKeyRepository,
	tokenService TokenService,
	hub *WSHub,
	sessions *SessionRegistry,
	pushService PushService,
	cfg WSServiceConfig,
) WSService {
	return &wsServiceImpl{
		machines:     machines,
		masterKeys:   masterKeys,
		tokenService: tokenService,
		hub:          hub,
		sessions:     sessions,
		pushService:  pushService,
		cfg:          cfg,
	}
}

type wsEnvelope struct {
	Type WSType `json:"type"`
}

type registerMessage struct {
	Type         WSType `json:"type"`
	Role         WSRole `json:"role"`
	MachineID    string `json:"machine_id,omitempty"`
	Hostname     string `json:"hostname,omitempty"`
	ConnectToken string `json:"connect_token,omitempty"`
}

type challengeMessage struct {
	Type  WSType `json:"type"`
	Nonce string `json:"nonce"`
}

type challengeResponseMessage struct {
	Type      WSType `json:"type"`
	Signature string `json:"signature"`
}

type registeredMessage struct {
	Type      WSType `json:"type"`
	MasterID  string `json:"master_id,omitempty"`
	MachineID string `json:"machine_id,omitempty"`
}

type sessionInitMessage struct {
	Type               WSType `json:"type"`
	MachineID          string `json:"machine_id"`
	MachineToken       string `json:"machine_token"`
	ClientEphemeralPub string `json:"client_ephemeral_pub"`
	Signature          string `json:"signature"`
	Force              bool   `json:"force,omitempty"`
}

type sessionAckMessage struct {
	Type                WSType `json:"type"`
	MachineID           string `json:"machine_id"`
	MachineEphemeralPub string `json:"machine_ephemeral_pub"`
	Signature           string `json:"signature"`
}

type sessionEndMessage struct {
	Type      WSType `json:"type"`
	MachineID string `json:"machine_id"`
}

type eventHint struct {
	Event string `json:"event"`
}

type encryptedMessage struct {
	Type       WSType     `json:"type"`
	MachineID  string     `json:"machine_id"`
	MsgID      string     `json:"msg_id"`
	Nonce      string     `json:"nonce"`
	Ciphertext string     `json:"ciphertext"`
	Hint       *eventHint `json:"hint,omitempty"`
}

type errorMessage struct {
	Type  WSType `json:"type"`
	Error string `json:"error"`
}

type machineStatusMessage struct {
	Type      WSType `json:"type"`
	MachineID string `json:"machine_id"`
	Hostname  string `json:"hostname"`
}

func (s *wsServiceImpl) HandleConnection(ctx context.Context, conn *websocket.Conn) {
	lc := &lockedConn{conn: conn}

	var role WSRole
	var clientID uuid.UUID
	var clientClaims ConnectTokenClaims
	var machineID uuid.UUID

	var pendingNonce []byte
	var pendingMachineID uuid.UUID
	var pendingMachineMasterID uuid.UUID
	var pendingMachineSignPub []byte
	var pendingHostname string

	// --- Register timeout via read deadline ---
	// Before registration, read deadline is clamped to registerDeadline so
	// unregistered connections are dropped after RegisterTimeout.
	registerDeadline := time.Now().Add(s.cfg.RegisterTimeout)

	heartbeatDeadline := func() time.Time {
		return time.Now().Add(pingInterval + pongTimeout)
	}
	clampedDeadline := func() time.Time {
		d := heartbeatDeadline()
		if role == "" && registerDeadline.Before(d) {
			d = registerDeadline
		}
		return d
	}

	conn.SetPongHandler(func(string) error {
		return conn.SetReadDeadline(clampedDeadline())
	})
	_ = conn.SetReadDeadline(clampedDeadline())

	// Ping ticker — WriteControl is explicitly concurrency-safe in gorilla,
	// so it bypasses lockedConn intentionally.
	done := make(chan struct{})
	defer close(done)
	go func() {
		ticker := time.NewTicker(pingInterval)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				if err := conn.WriteControl(
					websocket.PingMessage, nil,
					time.Now().Add(writeWait),
				); err != nil {
					return
				}
			case <-done:
				return
			}
		}
	}()

	// --- Inbound bandwidth limiter (per-connection) ---
	// Burst clamped to min(5MB, budget) so configs below 5MB actually limit
	// single-message size rather than being silently ignored.
	var bwLimiter *rate.Limiter
	if s.cfg.InboundBytesPerMin > 0 {
		burst := 5 * 1024 * 1024 // matches SetReadLimit
		if s.cfg.InboundBytesPerMin < int64(burst) {
			burst = int(s.cfg.InboundBytesPerMin)
		}
		bwLimiter = rate.NewLimiter(rate.Limit(float64(s.cfg.InboundBytesPerMin)/60), burst)
	}

	defer func() {
		switch role {
		case WSRoleClient:
			if clientID != uuid.Nil {
				s.hub.UnregisterClient(clientID)
				s.sessions.EndSessionsForClient(clientID)
			}
		case WSRoleMachine:
			if machineID != uuid.Nil {
				if mc, ok := s.hub.GetMachine(machineID); ok {
					s.notifyMachineStatus(mc.MasterID, machineID, mc.Hostname, false)
				}
				if cID, ok := s.sessions.GetSessionClient(machineID); ok {
					if cc, ok := s.hub.GetClient(cID); ok {
						_ = cc.conn.WriteJSON(sessionEndMessage{
							Type:      WSTypeSessionEnd,
							MachineID: machineID.String(),
						})
					}
				}
				s.hub.UnregisterMachine(machineID)
				s.sessions.EndSession(machineID)
			}
		}
	}()

	for {
		_, raw, err := conn.ReadMessage()
		if err != nil {
			return
		}

		// Bandwidth check: drop connection if sustained inbound rate exceeded.
		if bwLimiter != nil && !bwLimiter.AllowN(time.Now(), len(raw)) {
			_ = conn.WriteControl(websocket.CloseMessage,
				websocket.FormatCloseMessage(websocket.ClosePolicyViolation, "bandwidth limit exceeded"),
				time.Now().Add(writeWait))
			return
		}

		var envelope wsEnvelope
		if err := json.Unmarshal(raw, &envelope); err != nil {
			if sendWSError(lc, "invalid JSON") != nil {
				return
			}
			continue
		}

		if envelope.Type == "" {
			if sendWSError(lc, "invalid message type") != nil {
				return
			}
			continue
		}

		if role == "" {
			if envelope.Type != WSTypeRegister && envelope.Type != WSTypeChallengeResponse {
				if sendWSError(lc, "registration required") != nil {
					return
				}
				continue
			}
		}

		switch envelope.Type {
		case WSTypeRegister:
			if role != "" {
				if sendWSError(lc, "already registered") != nil {
					return
				}
				continue
			}
			var msg registerMessage
			if err := json.Unmarshal(raw, &msg); err != nil {
				if sendWSError(lc, "invalid register message") != nil {
					return
				}
				continue
			}
			if msg.Type != WSTypeRegister {
				if sendWSError(lc, "invalid register type") != nil {
					return
				}
				continue
			}
			switch msg.Role {
			case WSRoleMachine:
				if msg.MachineID == "" {
					if sendWSError(lc, "machine_id required") != nil {
						return
					}
					continue
				}
				parsedID, err := uuid.Parse(msg.MachineID)
				if err != nil {
					if sendWSError(lc, "invalid machine_id") != nil {
						return
					}
					continue
				}
				machine, err := s.machines.FindByID(ctx, parsedID)
				if err != nil {
					switch {
					case errors.Is(err, repository.ErrMachineNotFound):
						if sendWSError(lc, ErrUnknownMachine.Error()) != nil {
							return
						}
					default:
						if sendWSError(lc, "unknown machine") != nil {
							return
						}
					}
					continue
				}
				if machine.RevokedAt != nil {
					if sendWSError(lc, ErrMachineRevoked.Error()) != nil {
						return
					}
					continue
				}

				nonce := make([]byte, 32)
				if _, err := rand.Read(nonce); err != nil {
					if sendWSError(lc, "failed to generate challenge") != nil {
						return
					}
					continue
				}
				pendingNonce = nonce
				pendingMachineID = parsedID
				pendingMachineMasterID = machine.MasterID
				pendingMachineSignPub = machine.MachineSignPub
				pendingHostname = msg.Hostname
				if err := lc.WriteJSON(challengeMessage{
					Type:  WSTypeChallenge,
					Nonce: base64.StdEncoding.EncodeToString(nonce),
				}); err != nil {
					return
				}
			case WSRoleClient:
				if msg.ConnectToken == "" {
					if sendWSError(lc, "connect_token required") != nil {
						return
					}
					continue
				}
				claims, err := s.tokenService.VerifyConnectToken(ctx, msg.ConnectToken)
				if err != nil {
					if sendWSError(lc, err.Error()) != nil {
						return
					}
					continue
				}
				clientID = uuid.New()
				role = WSRoleClient
				clientClaims = claims
				_ = conn.SetReadDeadline(heartbeatDeadline()) // registered: lift register timeout
				s.hub.RegisterClient(clientID, claims.MasterID, claims.MasterSignKeyFingerprint, lc)
				if err := lc.WriteJSON(registeredMessage{
					Type:     WSTypeRegistered,
					MasterID: claims.MasterID.String(),
				}); err != nil {
					s.hub.UnregisterClient(clientID)
					return
				}
			default:
				if sendWSError(lc, "invalid role") != nil {
					return
				}
			}

		case WSTypeChallengeResponse:
			if pendingNonce == nil || pendingMachineID == uuid.Nil {
				if sendWSError(lc, "no pending challenge") != nil {
					return
				}
				continue
			}
			var msg challengeResponseMessage
			if err := json.Unmarshal(raw, &msg); err != nil {
				if sendWSError(lc, "invalid challenge response") != nil {
					return
				}
				continue
			}
			if msg.Type != WSTypeChallengeResponse {
				if sendWSError(lc, "invalid challenge response type") != nil {
					return
				}
				continue
			}
			if msg.Signature == "" {
				if sendWSError(lc, "signature required") != nil {
					return
				}
				continue
			}
			sigBytes, err := base64.StdEncoding.DecodeString(msg.Signature)
			if err != nil {
				if sendWSError(lc, "invalid signature") != nil {
					return
				}
				continue
			}
			nonceB64 := base64.StdEncoding.EncodeToString(pendingNonce)
			signedMsg := crypto.BuildMachineAuthMessage(pendingMachineID.String(), nonceB64)
			if !crypto.VerifySignature(pendingMachineSignPub, []byte(signedMsg), sigBytes) {
				if sendWSError(lc, "invalid signature") != nil {
					return
				}
				continue
			}

			if err := s.machines.UpdateLastSeenAndHostname(ctx, pendingMachineID, time.Now(), pendingHostname); err != nil {
				if sendWSError(lc, "failed to register machine") != nil {
					return
				}
				return
			}

			role = WSRoleMachine
			machineID = pendingMachineID
			_ = conn.SetReadDeadline(heartbeatDeadline()) // registered: lift register timeout
			s.hub.RegisterMachine(machineID, pendingMachineMasterID, pendingHostname, lc)
			s.notifyMachineStatus(pendingMachineMasterID, machineID, pendingHostname, true)

			pendingNonce = nil
			pendingMachineID = uuid.Nil
			pendingMachineSignPub = nil
			if err := lc.WriteJSON(registeredMessage{
				Type:      WSTypeRegistered,
				MachineID: machineID.String(),
			}); err != nil {
				s.hub.UnregisterMachine(machineID)
				return
			}

		case WSTypeSessionInit:
			if role != WSRoleClient {
				if sendWSError(lc, "client role required") != nil {
					return
				}
				continue
			}
			var msg sessionInitMessage
			if err := json.Unmarshal(raw, &msg); err != nil {
				if sendWSError(lc, "invalid session-init") != nil {
					return
				}
				continue
			}
			if msg.Type != WSTypeSessionInit {
				if sendWSError(lc, "invalid session-init type") != nil {
					return
				}
				continue
			}
			if err := s.handleSessionInit(ctx, clientID, clientClaims, msg, raw); err != nil {
				if sendWSError(lc, err.Error()) != nil {
					return
				}
			}

		case WSTypeSessionAck:
			if role != WSRoleMachine {
				if sendWSError(lc, "machine role required") != nil {
					return
				}
				continue
			}
			var msg sessionAckMessage
			if err := json.Unmarshal(raw, &msg); err != nil {
				if sendWSError(lc, "invalid session-ack") != nil {
					return
				}
				continue
			}
			if msg.Type != WSTypeSessionAck {
				if sendWSError(lc, "invalid session-ack type") != nil {
					return
				}
				continue
			}
			if err := s.handleSessionAck(ctx, machineID, msg, raw); err != nil {
				if sendWSError(lc, err.Error()) != nil {
					return
				}
			}

		case WSTypeSessionEnd:
			if role != WSRoleClient {
				if sendWSError(lc, "client role required") != nil {
					return
				}
				continue
			}
			var msg sessionEndMessage
			if err := json.Unmarshal(raw, &msg); err != nil {
				if sendWSError(lc, "invalid session-end") != nil {
					return
				}
				continue
			}
			if msg.Type != WSTypeSessionEnd {
				if sendWSError(lc, "invalid session-end type") != nil {
					return
				}
				continue
			}
			if err := s.handleSessionEnd(ctx, clientID, msg, raw); err != nil {
				if sendWSError(lc, err.Error()) != nil {
					return
				}
			}

		case WSTypeRPC, WSTypeResponse, WSTypeEvent:
			switch role {
			case WSRoleClient:
				if err := s.forwardClientMessage(raw, clientID); err != nil {
					if sendWSError(lc, err.Error()) != nil {
						return
					}
				}
			case WSRoleMachine:
				if err := s.forwardMachineMessage(raw, machineID); err != nil {
					if sendWSError(lc, err.Error()) != nil {
						return
					}
				}
			default:
				if sendWSError(lc, "registration required") != nil {
					return
				}
			}

		case WSTypeError:
			continue
		default:
			if sendWSError(lc, "unknown message type") != nil {
				return
			}
		}
	}
}

func (s *wsServiceImpl) handleSessionInit(ctx context.Context, clientID uuid.UUID, claims ConnectTokenClaims, msg sessionInitMessage, raw json.RawMessage) error {
	if msg.MachineID == "" || msg.MachineToken == "" || msg.ClientEphemeralPub == "" || msg.Signature == "" {
		return ErrInvalidSessionInit
	}
	machineID, err := uuid.Parse(msg.MachineID)
	if err != nil {
		return ErrInvalidSessionInit
	}
	tokenClaims, err := s.tokenService.VerifyMachineToken(ctx, msg.MachineToken)
	if err != nil {
		return err
	}
	if tokenClaims.MasterID != claims.MasterID || tokenClaims.MachineID != machineID {
		return ErrInvalidMachineToken
	}
	if tokenClaims.MasterSignKeyFingerprint != claims.MasterSignKeyFingerprint {
		return ErrInvalidMachineToken
	}
	machine, err := s.machines.FindByID(ctx, machineID)
	if err != nil {
		if errors.Is(err, repository.ErrMachineNotFound) {
			return ErrUnknownMachine
		}
		return err
	}
	if machine.RevokedAt != nil {
		return ErrMachineRevoked
	}
	if machine.MasterID != claims.MasterID {
		return ErrUnauthorizedMachine
	}
	signerKey, err := s.masterKeys.FindByMasterAndFingerprint(ctx, claims.MasterID, tokenClaims.MasterSignKeyFingerprint)
	if err != nil {
		return ErrInvalidMachineToken
	}
	signedMsg := crypto.BuildSessionInitMessage(machineID.String(), msg.ClientEphemeralPub)
	sigBytes, err := base64.StdEncoding.DecodeString(msg.Signature)
	if err != nil || !crypto.VerifySignature(signerKey.MasterSignPub, []byte(signedMsg), sigBytes) {
		return ErrInvalidSessionInit
	}

	if err := s.sessions.BeginSession(machineID, clientID, msg.Force); err != nil {
		return err
	}
	machineConn, ok := s.hub.GetMachine(machineID)
	if !ok {
		s.sessions.EndSession(machineID)
		return ErrMachineNotConnected
	}

	if err := machineConn.conn.WriteMessage(websocket.TextMessage, raw); err != nil {
		s.sessions.EndSession(machineID)
		return ErrMachineNotConnected
	}
	return nil
}

func (s *wsServiceImpl) handleSessionAck(ctx context.Context, machineID uuid.UUID, msg sessionAckMessage, raw json.RawMessage) error {
	if msg.MachineID == "" || msg.MachineEphemeralPub == "" || msg.Signature == "" {
		return ErrInvalidSessionInit
	}
	parsed, err := uuid.Parse(msg.MachineID)
	if err != nil || parsed != machineID {
		return ErrInvalidSessionInit
	}
	clientID, ok := s.sessions.GetSessionClient(machineID)
	if !ok {
		return ErrUnauthorizedSession
	}
	machine, err := s.machines.FindByID(ctx, machineID)
	if err != nil {
		return ErrUnknownMachine
	}
	signedMsg := crypto.BuildSessionAckMessage(machineID.String(), msg.MachineEphemeralPub)
	sigBytes, err := base64.StdEncoding.DecodeString(msg.Signature)
	if err != nil || !crypto.VerifySignature(machine.MachineSignPub, []byte(signedMsg), sigBytes) {
		return ErrInvalidSessionInit
	}
	if err := s.sessions.ActivateSession(machineID); err != nil {
		return err
	}
	clientConn, ok := s.hub.GetClient(clientID)
	if !ok {
		s.sessions.EndSession(machineID)
		return ErrUnauthorizedSession
	}
	if err := clientConn.conn.WriteMessage(websocket.TextMessage, raw); err != nil {
		s.sessions.EndSession(machineID)
		return ErrUnauthorizedSession
	}
	return nil
}

func (s *wsServiceImpl) handleSessionEnd(ctx context.Context, clientID uuid.UUID, msg sessionEndMessage, raw json.RawMessage) error {
	if msg.MachineID == "" {
		return ErrInvalidSessionInit
	}
	machineID, err := uuid.Parse(msg.MachineID)
	if err != nil {
		return ErrInvalidSessionInit
	}
	owner, ok := s.sessions.GetActiveSessionClient(machineID)
	if !ok || owner != clientID {
		return ErrUnauthorizedSession
	}
	s.sessions.EndSession(machineID)
	if machineConn, ok := s.hub.GetMachine(machineID); ok {
		_ = machineConn.conn.WriteMessage(websocket.TextMessage, raw)
	}
	return nil
}

func (s *wsServiceImpl) forwardClientMessage(raw json.RawMessage, clientID uuid.UUID) error {
	var msg encryptedMessage
	if err := json.Unmarshal(raw, &msg); err != nil || msg.MachineID == "" {
		return ErrInvalidRequest
	}
	machineID, err := uuid.Parse(msg.MachineID)
	if err != nil {
		return ErrInvalidRequest
	}
	owner, ok := s.sessions.GetActiveSessionClient(machineID)
	if !ok || owner != clientID {
		return ErrUnauthorizedSession
	}
	machineConn, ok := s.hub.GetMachine(machineID)
	if !ok {
		return ErrMachineNotConnected
	}
	if err := machineConn.conn.WriteMessage(websocket.TextMessage, raw); err != nil {
		s.sessions.EndSession(machineID)
		return ErrMachineNotConnected
	}
	return nil
}

func (s *wsServiceImpl) forwardMachineMessage(raw json.RawMessage, machineID uuid.UUID) error {
	clientID, ok := s.sessions.GetActiveSessionClient(machineID)
	if !ok {
		return ErrUnauthorizedSession
	}
	clientConn, ok := s.hub.GetClient(clientID)
	if !ok {
		s.sessions.EndSession(machineID)
		s.tryPushNotification(raw, machineID)
		return ErrUnauthorizedSession
	}
	if err := clientConn.conn.WriteMessage(websocket.TextMessage, raw); err != nil {
		s.sessions.EndSession(machineID)
		s.tryPushNotification(raw, machineID)
		return ErrUnauthorizedSession
	}
	return nil
}

func (s *wsServiceImpl) tryPushNotification(raw json.RawMessage, machineID uuid.UUID) {
	var msg encryptedMessage
	if err := json.Unmarshal(raw, &msg); err != nil {
		return
	}
	if msg.Hint == nil {
		return
	}
	mc, ok := s.hub.GetMachine(machineID)
	if !ok {
		return
	}
	go s.pushService.SendPushIfOffline(context.Background(), mc.MasterID, EventHint{Event: msg.Hint.Event})
}

func (s *wsServiceImpl) notifyMachineStatus(masterID, machineID uuid.UUID, hostname string, online bool) {
	msgType := WSTypeMachineOffline
	if online {
		msgType = WSTypeMachineOnline
	}
	msg := machineStatusMessage{
		Type:      msgType,
		MachineID: machineID.String(),
		Hostname:  hostname,
	}
	clients := s.hub.GetClientsByMasterID(masterID)
	for _, c := range clients {
		_ = c.conn.WriteJSON(msg)
	}
}

func sendWSError(conn *lockedConn, message string) error {
	return conn.WriteJSON(errorMessage{Type: WSTypeError, Error: message})
}
