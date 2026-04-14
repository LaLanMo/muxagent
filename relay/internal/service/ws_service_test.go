package service

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/LaLanMo/muxagent/relay/internal/domain"
	"github.com/LaLanMo/muxagent/relay/internal/infra/crypto"
	"github.com/LaLanMo/muxagent/relay/internal/logging"
	"github.com/LaLanMo/muxagent/relay/internal/repository"
	"github.com/LaLanMo/muxagent/relay/internal/testutil"
	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func testWSServiceConfig() WSServiceConfig {
	return WSServiceConfig{
		InboundBytesPerMin: 0, // disabled in tests
		RegisterTimeout:    30 * time.Second,
	}
}

type tokenServiceMock struct {
	verifyConnectFn       func(ctx context.Context, token string) (ConnectTokenClaims, error)
	verifyMachineFn       func(ctx context.Context, token string) (MachineTokenClaims, error)
	verifyMachineAccessFn func(ctx context.Context, token string) (MachineAccessTokenClaims, error)
}

func (m *tokenServiceMock) VerifyConnectToken(ctx context.Context, token string) (ConnectTokenClaims, error) {
	if m.verifyConnectFn != nil {
		return m.verifyConnectFn(ctx, token)
	}
	return ConnectTokenClaims{}, ErrInvalidConnectToken
}

func (m *tokenServiceMock) VerifyMachineToken(ctx context.Context, token string) (MachineTokenClaims, error) {
	if m.verifyMachineFn != nil {
		return m.verifyMachineFn(ctx, token)
	}
	return MachineTokenClaims{}, ErrInvalidMachineToken
}

func (m *tokenServiceMock) VerifyMachineAccessToken(ctx context.Context, token string) (MachineAccessTokenClaims, error) {
	if m.verifyMachineAccessFn != nil {
		return m.verifyMachineAccessFn(ctx, token)
	}
	return MachineAccessTokenClaims{}, ErrInvalidMachineAccessToken
}

type machineRepoMock struct {
	findFn   func(ctx context.Context, id uuid.UUID) (domain.Machine, error)
	updateFn func(ctx context.Context, id uuid.UUID, lastSeen time.Time, hostname string) error
}

type pushCall struct {
	masterID uuid.UUID
	hint     EventHint
}

type capturingPushService struct {
	calls chan pushCall
}

func (s *capturingPushService) SendPushForHint(ctx context.Context, masterID uuid.UUID, hint EventHint) error {
	if s.calls != nil {
		s.calls <- pushCall{masterID: masterID, hint: hint}
	}
	return nil
}

func (m *machineRepoMock) Create(ctx context.Context, machine *domain.Machine) error {
	return nil
}

func (m *machineRepoMock) FindByID(ctx context.Context, id uuid.UUID) (domain.Machine, error) {
	if m.findFn != nil {
		return m.findFn(ctx, id)
	}
	return domain.Machine{}, repository.ErrMachineNotFound
}

func (m *machineRepoMock) UpdateLastSeenAndHostname(ctx context.Context, id uuid.UUID, lastSeen time.Time, hostname string) error {
	if m.updateFn != nil {
		return m.updateFn(ctx, id, lastSeen, hostname)
	}
	return nil
}

func newWSServer(t *testing.T, svc WSService) string {
	upgrader := websocket.Upgrader{CheckOrigin: func(r *http.Request) bool { return true }}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			return
		}
		go svc.HandleConnection(context.Background(), conn)
	}))
	t.Cleanup(srv.Close)
	return "ws" + strings.TrimPrefix(srv.URL, "http")
}

func dialWS(t *testing.T, url string) *websocket.Conn {
	conn, _, err := websocket.DefaultDialer.Dial(url, nil)
	require.NoError(t, err)
	t.Cleanup(func() { _ = conn.Close() })
	return conn
}

func readJSON(t *testing.T, conn *websocket.Conn, v any) {
	t.Helper()
	require.NoError(t, conn.SetReadDeadline(time.Now().Add(2*time.Second)))
	require.NoError(t, conn.ReadJSON(v))
}

func TestWSService_RegisterMachineAndClient(t *testing.T) {
	buf := testutil.CaptureSlog(t)

	masterID := uuid.New()
	machineID := uuid.New()
	machineSignPub, machineSignPriv, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)

	machineRepo := &machineRepoMock{
		findFn: func(ctx context.Context, id uuid.UUID) (domain.Machine, error) {
			return domain.Machine{
				ID:             machineID,
				MasterID:       masterID,
				MachineSignPub: machineSignPub,
			}, nil
		},
	}

	tokens := &tokenServiceMock{
		verifyConnectFn: func(ctx context.Context, token string) (ConnectTokenClaims, error) {
			if token != "connect" {
				return ConnectTokenClaims{}, ErrInvalidConnectToken
			}
			return ConnectTokenClaims{MasterID: masterID, MasterSignKeyFingerprint: "fp"}, nil
		},
	}

	svc := NewWSService(machineRepo, &masterKeyRepoMock{}, tokens, NewWSHub(), NewSessionRegistry(), NewPushService(nil, nil), testWSServiceConfig())
	wsURL := newWSServer(t, svc)

	machineConn := dialWS(t, wsURL)
	require.NoError(t, machineConn.WriteJSON(registerMessage{
		Type:      WSTypeRegister,
		Role:      WSRoleMachine,
		MachineID: machineID.String(),
		Hostname:  "host",
	}))

	var challenge challengeMessage
	readJSON(t, machineConn, &challenge)
	assert.Equal(t, WSTypeChallenge, challenge.Type)
	require.NotEmpty(t, challenge.Nonce)

	signedMsg := crypto.BuildMachineAuthMessage(machineID.String(), challenge.Nonce)
	sig := ed25519.Sign(machineSignPriv, []byte(signedMsg))
	require.NoError(t, machineConn.WriteJSON(challengeResponseMessage{
		Type:      WSTypeChallengeResponse,
		Signature: base64.StdEncoding.EncodeToString(sig),
	}))

	var registered registeredMessage
	readJSON(t, machineConn, &registered)
	assert.Equal(t, WSTypeRegistered, registered.Type)
	assert.Equal(t, machineID.String(), registered.MachineID)

	clientConn := dialWS(t, wsURL)
	require.NoError(t, clientConn.WriteJSON(registerMessage{
		Type:         WSTypeRegister,
		Role:         WSRoleClient,
		ConnectToken: "connect",
	}))

	var clientRegistered registeredMessage
	readJSON(t, clientConn, &clientRegistered)
	assert.Equal(t, WSTypeRegistered, clientRegistered.Type)
	assert.Equal(t, masterID.String(), clientRegistered.MasterID)

	require.Eventually(t, func() bool {
		logs := buf.String()
		return strings.Contains(logs, logging.EventWSMachineRegistered) &&
			strings.Contains(logs, logging.EventWSClientRegistered)
	}, time.Second, 10*time.Millisecond)

	entries := testutil.ParseLogEntries(t, buf)
	machineEntry := testutil.FindEntryByEvent(entries, logging.EventWSMachineRegistered)
	require.NotNil(t, machineEntry)
	assert.Equal(t, logging.ResultSuccess, machineEntry["result"])
	assert.Equal(t, machineID.String(), machineEntry["machine_id"])
	assert.Equal(t, masterID.String(), machineEntry["master_id"])

	clientEntry := testutil.FindEntryByEvent(entries, logging.EventWSClientRegistered)
	require.NotNil(t, clientEntry)
	assert.Equal(t, logging.ResultSuccess, clientEntry["result"])
	assert.Equal(t, masterID.String(), clientEntry["master_id"])
	assert.Equal(t, "fp", clientEntry["master_sign_key_fingerprint"])
	assert.NotEmpty(t, clientEntry["client_id"])
	assert.NotContains(t, buf.String(), "connect")
}

func TestWSService_RegisterClientWithInvalidToken_LogsRejected(t *testing.T) {
	buf := testutil.CaptureSlog(t)

	tokens := &tokenServiceMock{
		verifyConnectFn: func(ctx context.Context, token string) (ConnectTokenClaims, error) {
			return ConnectTokenClaims{}, ErrInvalidConnectToken
		},
	}

	svc := NewWSService(
		&machineRepoMock{},
		&masterKeyRepoMock{},
		tokens,
		NewWSHub(),
		NewSessionRegistry(),
		NewPushService(nil, nil),
		testWSServiceConfig(),
	)
	wsURL := newWSServer(t, svc)

	clientConn := dialWS(t, wsURL)
	require.NoError(t, clientConn.WriteJSON(registerMessage{
		Type:         WSTypeRegister,
		Role:         WSRoleClient,
		ConnectToken: "bad-connect-token",
	}))

	var errMsg errorMessage
	readJSON(t, clientConn, &errMsg)
	assert.Equal(t, WSTypeError, errMsg.Type)
	assert.Equal(t, ErrInvalidConnectToken.Error(), errMsg.Error)

	require.Eventually(t, func() bool {
		return strings.Contains(buf.String(), logging.EventWSRegistrationDenied)
	}, time.Second, 10*time.Millisecond)

	entry := testutil.FindEntryByEvent(testutil.ParseLogEntries(t, buf), logging.EventWSRegistrationDenied)
	require.NotNil(t, entry)
	assert.Equal(t, logging.ResultRejected, entry["result"])
	assert.Equal(t, ErrInvalidConnectToken.Error(), entry["reason"])
	assert.NotContains(t, buf.String(), "bad-connect-token")
}

func TestWSService_InvalidSessionInit_LogsRejected(t *testing.T) {
	buf := testutil.CaptureSlog(t)

	masterID := uuid.New()
	machineID := uuid.New()
	tokens := &tokenServiceMock{
		verifyConnectFn: func(ctx context.Context, token string) (ConnectTokenClaims, error) {
			if token != "connect" {
				return ConnectTokenClaims{}, ErrInvalidConnectToken
			}
			return ConnectTokenClaims{MasterID: masterID, MasterSignKeyFingerprint: "fp"}, nil
		},
		verifyMachineFn: func(ctx context.Context, token string) (MachineTokenClaims, error) {
			return MachineTokenClaims{}, ErrInvalidMachineToken
		},
	}

	svc := NewWSService(
		&machineRepoMock{},
		&masterKeyRepoMock{},
		tokens,
		NewWSHub(),
		NewSessionRegistry(),
		NewPushService(nil, nil),
		testWSServiceConfig(),
	)
	wsURL := newWSServer(t, svc)

	clientConn := dialWS(t, wsURL)
	require.NoError(t, clientConn.WriteJSON(registerMessage{
		Type:         WSTypeRegister,
		Role:         WSRoleClient,
		ConnectToken: "connect",
	}))
	readJSON(t, clientConn, &registeredMessage{})

	require.NoError(t, clientConn.WriteJSON(sessionInitMessage{
		Type:               WSTypeSessionInit,
		MachineID:          machineID.String(),
		MachineToken:       "bad-machine-token",
		ClientEphemeralPub: "client-ephemeral",
		Signature:          "sig",
	}))

	var errMsg errorMessage
	readJSON(t, clientConn, &errMsg)
	assert.Equal(t, WSTypeError, errMsg.Type)
	assert.Equal(t, ErrInvalidMachineToken.Error(), errMsg.Error)

	require.Eventually(t, func() bool {
		return strings.Contains(buf.String(), logging.EventWSSessionRejected)
	}, time.Second, 10*time.Millisecond)

	entry := testutil.FindEntryByEvent(testutil.ParseLogEntries(t, buf), logging.EventWSSessionRejected)
	require.NotNil(t, entry)
	assert.Equal(t, logging.ResultRejected, entry["result"])
	assert.Equal(t, ErrInvalidMachineToken.Error(), entry["reason"])
	assert.Equal(t, machineID.String(), entry["machine_id"])
	assert.NotEmpty(t, entry["client_id"])
	assert.NotContains(t, buf.String(), "bad-machine-token")
}

func TestWSService_SessionInitAckRouting(t *testing.T) {
	masterID := uuid.New()
	machineID := uuid.New()

	masterSignPub, masterSignPriv, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)
	masterFingerprint := crypto.HashKeyFingerprint(masterSignPub)

	machineSignPub, machineSignPriv, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)

	machineRepo := &machineRepoMock{
		findFn: func(ctx context.Context, id uuid.UUID) (domain.Machine, error) {
			return domain.Machine{
				ID:             machineID,
				MasterID:       masterID,
				MachineSignPub: machineSignPub,
			}, nil
		},
	}
	masterKeys := &masterKeyRepoMock{
		findByMasterFingerprintFn: func(ctx context.Context, id uuid.UUID, fingerprint string) (domain.MasterKey, error) {
			if fingerprint != masterFingerprint {
				return domain.MasterKey{}, repository.ErrMasterKeyNotFound
			}
			return domain.MasterKey{MasterSignPub: masterSignPub}, nil
		},
	}

	tokens := &tokenServiceMock{
		verifyConnectFn: func(ctx context.Context, token string) (ConnectTokenClaims, error) {
			if token != "connect" {
				return ConnectTokenClaims{}, ErrInvalidConnectToken
			}
			return ConnectTokenClaims{MasterID: masterID, MasterSignKeyFingerprint: masterFingerprint}, nil
		},
		verifyMachineFn: func(ctx context.Context, token string) (MachineTokenClaims, error) {
			if token != "machine" {
				return MachineTokenClaims{}, ErrInvalidMachineToken
			}
			return MachineTokenClaims{MasterID: masterID, MachineID: machineID, MasterSignKeyFingerprint: masterFingerprint}, nil
		},
	}

	svc := NewWSService(machineRepo, masterKeys, tokens, NewWSHub(), NewSessionRegistry(), NewPushService(nil, nil), testWSServiceConfig())
	wsURL := newWSServer(t, svc)

	machineConn := dialWS(t, wsURL)
	require.NoError(t, machineConn.WriteJSON(registerMessage{
		Type:      WSTypeRegister,
		Role:      WSRoleMachine,
		MachineID: machineID.String(),
		Hostname:  "host",
	}))

	var challenge challengeMessage
	readJSON(t, machineConn, &challenge)
	signedMsg := crypto.BuildMachineAuthMessage(machineID.String(), challenge.Nonce)
	sig := ed25519.Sign(machineSignPriv, []byte(signedMsg))
	require.NoError(t, machineConn.WriteJSON(challengeResponseMessage{
		Type:      WSTypeChallengeResponse,
		Signature: base64.StdEncoding.EncodeToString(sig),
	}))
	var registered registeredMessage
	readJSON(t, machineConn, &registered)

	clientConn := dialWS(t, wsURL)
	require.NoError(t, clientConn.WriteJSON(registerMessage{
		Type:         WSTypeRegister,
		Role:         WSRoleClient,
		ConnectToken: "connect",
	}))
	readJSON(t, clientConn, &registeredMessage{})

	clientEphemeral := "client-ephemeral"
	initMsg := crypto.BuildSessionInitMessage(machineID.String(), clientEphemeral)
	initSig := ed25519.Sign(masterSignPriv, []byte(initMsg))
	initSigB64 := base64.StdEncoding.EncodeToString(initSig)

	require.NoError(t, clientConn.WriteJSON(sessionInitMessage{
		Type:               WSTypeSessionInit,
		MachineID:          machineID.String(),
		MachineToken:       "machine",
		ClientEphemeralPub: clientEphemeral,
		Signature:          initSigB64,
	}))

	var initReceived sessionInitMessage
	readJSON(t, machineConn, &initReceived)
	assert.Equal(t, WSTypeSessionInit, initReceived.Type)
	assert.Equal(t, machineID.String(), initReceived.MachineID)
	assert.Equal(t, "machine", initReceived.MachineToken)
	assert.Equal(t, clientEphemeral, initReceived.ClientEphemeralPub)
	assert.Equal(t, initSigB64, initReceived.Signature)

	machineEphemeral := "machine-ephemeral"
	ackMsg := crypto.BuildSessionAckMessage(machineID.String(), machineEphemeral)
	ackSig := ed25519.Sign(machineSignPriv, []byte(ackMsg))
	ackSigB64 := base64.StdEncoding.EncodeToString(ackSig)

	require.NoError(t, machineConn.WriteJSON(sessionAckMessage{
		Type:                WSTypeSessionAck,
		MachineID:           machineID.String(),
		MachineEphemeralPub: machineEphemeral,
		Signature:           ackSigB64,
	}))

	var ackReceived sessionAckMessage
	readJSON(t, clientConn, &ackReceived)
	assert.Equal(t, WSTypeSessionAck, ackReceived.Type)
	assert.Equal(t, machineID.String(), ackReceived.MachineID)
	assert.Equal(t, machineEphemeral, ackReceived.MachineEphemeralPub)
	assert.Equal(t, ackSigB64, ackReceived.Signature)

	rpcPayload := encryptedMessage{
		Type:       WSTypeRPC,
		MachineID:  machineID.String(),
		MsgID:      "1",
		Nonce:      "n",
		Ciphertext: "c",
	}
	require.NoError(t, clientConn.WriteJSON(rpcPayload))

	var rpcReceived encryptedMessage
	readJSON(t, machineConn, &rpcReceived)
	assert.Equal(t, WSTypeRPC, rpcReceived.Type)
	assert.Equal(t, rpcPayload.MachineID, rpcReceived.MachineID)
	assert.Equal(t, rpcPayload.MsgID, rpcReceived.MsgID)
	assert.Equal(t, rpcPayload.Nonce, rpcReceived.Nonce)
	assert.Equal(t, rpcPayload.Ciphertext, rpcReceived.Ciphertext)

	respPayload := encryptedMessage{
		Type:       WSTypeResponse,
		MachineID:  machineID.String(),
		MsgID:      "1",
		Nonce:      "n",
		Ciphertext: "c",
	}
	require.NoError(t, machineConn.WriteJSON(respPayload))

	var respReceived encryptedMessage
	readJSON(t, clientConn, &respReceived)
	assert.Equal(t, WSTypeResponse, respReceived.Type)
	assert.Equal(t, respPayload.MachineID, respReceived.MachineID)
	assert.Equal(t, respPayload.MsgID, respReceived.MsgID)
	assert.Equal(t, respPayload.Nonce, respReceived.Nonce)
	assert.Equal(t, respPayload.Ciphertext, respReceived.Ciphertext)
}

func TestWSService_RejectRPCWithoutActiveSession(t *testing.T) {
	masterID := uuid.New()
	machineID := uuid.New()
	machineSignPub, machineSignPriv, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)

	machineRepo := &machineRepoMock{
		findFn: func(ctx context.Context, id uuid.UUID) (domain.Machine, error) {
			return domain.Machine{
				ID:             machineID,
				MasterID:       masterID,
				MachineSignPub: machineSignPub,
			}, nil
		},
	}

	tokens := &tokenServiceMock{
		verifyConnectFn: func(ctx context.Context, token string) (ConnectTokenClaims, error) {
			return ConnectTokenClaims{MasterID: masterID, MasterSignKeyFingerprint: "fp"}, nil
		},
	}

	svc := NewWSService(machineRepo, &masterKeyRepoMock{}, tokens, NewWSHub(), NewSessionRegistry(), NewPushService(nil, nil), testWSServiceConfig())
	wsURL := newWSServer(t, svc)

	machineConn := dialWS(t, wsURL)
	require.NoError(t, machineConn.WriteJSON(registerMessage{
		Type:      WSTypeRegister,
		Role:      WSRoleMachine,
		MachineID: machineID.String(),
		Hostname:  "host",
	}))
	var challenge challengeMessage
	readJSON(t, machineConn, &challenge)
	signedMsg := crypto.BuildMachineAuthMessage(machineID.String(), challenge.Nonce)
	sig := ed25519.Sign(machineSignPriv, []byte(signedMsg))
	require.NoError(t, machineConn.WriteJSON(challengeResponseMessage{
		Type:      WSTypeChallengeResponse,
		Signature: base64.StdEncoding.EncodeToString(sig),
	}))
	readJSON(t, machineConn, &registeredMessage{})

	clientConn := dialWS(t, wsURL)
	require.NoError(t, clientConn.WriteJSON(registerMessage{
		Type:         WSTypeRegister,
		Role:         WSRoleClient,
		ConnectToken: "connect",
	}))
	readJSON(t, clientConn, &registeredMessage{})

	require.NoError(t, clientConn.WriteJSON(encryptedMessage{
		Type:       WSTypeRPC,
		MachineID:  machineID.String(),
		MsgID:      "1",
		Nonce:      "n",
		Ciphertext: "c",
	}))

	var errMsg errorMessage
	readJSON(t, clientConn, &errMsg)
	assert.Equal(t, WSTypeError, errMsg.Type)
	assert.NotEmpty(t, errMsg.Error)
}

func registerMachineWS(t *testing.T, conn *websocket.Conn, machineID uuid.UUID, machineSignPriv ed25519.PrivateKey, hostname string) {
	t.Helper()
	require.NoError(t, conn.WriteJSON(registerMessage{
		Type:      WSTypeRegister,
		Role:      WSRoleMachine,
		MachineID: machineID.String(),
		Hostname:  hostname,
	}))

	var challenge challengeMessage
	readJSON(t, conn, &challenge)
	signedMsg := crypto.BuildMachineAuthMessage(machineID.String(), challenge.Nonce)
	sig := ed25519.Sign(machineSignPriv, []byte(signedMsg))
	require.NoError(t, conn.WriteJSON(challengeResponseMessage{
		Type:      WSTypeChallengeResponse,
		Signature: base64.StdEncoding.EncodeToString(sig),
	}))

	var registered registeredMessage
	readJSON(t, conn, &registered)
	assert.Equal(t, WSTypeRegistered, registered.Type)
	assert.Equal(t, machineID.String(), registered.MachineID)
}

func TestWSService_RegisterRevokedMachineRejected(t *testing.T) {
	masterID := uuid.New()
	machineID := uuid.New()
	machineSignPub, _, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)
	revokedAt := time.Now()

	machineRepo := &machineRepoMock{
		findFn: func(ctx context.Context, id uuid.UUID) (domain.Machine, error) {
			return domain.Machine{
				ID:             machineID,
				MasterID:       masterID,
				MachineSignPub: machineSignPub,
				RevokedAt:      &revokedAt,
			}, nil
		},
	}

	svc := NewWSService(machineRepo, &masterKeyRepoMock{}, &tokenServiceMock{}, NewWSHub(), NewSessionRegistry(), NewPushService(nil, nil), testWSServiceConfig())
	wsURL := newWSServer(t, svc)

	machineConn := dialWS(t, wsURL)
	require.NoError(t, machineConn.WriteJSON(registerMessage{
		Type:      WSTypeRegister,
		Role:      WSRoleMachine,
		MachineID: machineID.String(),
		Hostname:  "host",
	}))

	var errMsg errorMessage
	readJSON(t, machineConn, &errMsg)
	assert.Equal(t, WSTypeError, errMsg.Type)
	assert.Equal(t, ErrMachineRevoked.Error(), errMsg.Error)
}

func TestWSService_RegisterMachineHostnameTooLongRejected(t *testing.T) {
	masterID := uuid.New()
	machineID := uuid.New()
	machineSignPub, _, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)

	machineRepo := &machineRepoMock{
		findFn: func(ctx context.Context, id uuid.UUID) (domain.Machine, error) {
			return domain.Machine{
				ID:             machineID,
				MasterID:       masterID,
				MachineSignPub: machineSignPub,
			}, nil
		},
	}

	svc := NewWSService(machineRepo, &masterKeyRepoMock{}, &tokenServiceMock{}, NewWSHub(), NewSessionRegistry(), NewPushService(nil, nil), testWSServiceConfig())
	wsURL := newWSServer(t, svc)

	machineConn := dialWS(t, wsURL)
	require.NoError(t, machineConn.WriteJSON(registerMessage{
		Type:      WSTypeRegister,
		Role:      WSRoleMachine,
		MachineID: machineID.String(),
		Hostname:  strings.Repeat("a", MaxHostnameBytes+1),
	}))

	var errMsg errorMessage
	readJSON(t, machineConn, &errMsg)
	assert.Equal(t, WSTypeError, errMsg.Type)
	assert.Equal(t, "hostname too long", errMsg.Error)
}

func TestWSService_DuplicateMachineRegistrationReplacesOldConnection(t *testing.T) {
	masterID := uuid.New()
	machineID := uuid.New()
	machineSignPub, machineSignPriv, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)

	hub := NewWSHub()
	machineRepo := &machineRepoMock{
		findFn: func(ctx context.Context, id uuid.UUID) (domain.Machine, error) {
			return domain.Machine{
				ID:             machineID,
				MasterID:       masterID,
				MachineSignPub: machineSignPub,
			}, nil
		},
	}

	svc := NewWSService(machineRepo, &masterKeyRepoMock{}, &tokenServiceMock{}, hub, NewSessionRegistry(), NewPushService(nil, nil), testWSServiceConfig())
	wsURL := newWSServer(t, svc)

	firstConn := dialWS(t, wsURL)
	registerMachineWS(t, firstConn, machineID, machineSignPriv, "host-1")

	secondConn := dialWS(t, wsURL)
	registerMachineWS(t, secondConn, machineID, machineSignPriv, "host-2")

	require.Eventually(t, func() bool {
		current, ok := hub.GetMachine(machineID)
		return ok && current.Hostname == "host-2"
	}, time.Second, 10*time.Millisecond)

	require.Eventually(t, func() bool {
		_ = firstConn.SetReadDeadline(time.Now().Add(20 * time.Millisecond))
		_, _, err := firstConn.ReadMessage()
		return err != nil
	}, time.Second, 10*time.Millisecond)

	current, ok := hub.GetMachine(machineID)
	require.True(t, ok)
	assert.Equal(t, "host-2", current.Hostname)

	require.NoError(t, secondConn.Close())
	require.Eventually(t, func() bool {
		_, ok := hub.GetMachine(machineID)
		return !ok
	}, time.Second, 10*time.Millisecond)
}

func TestWSService_ForwardMachineEventPushesWhenClientConnected(t *testing.T) {
	masterID := uuid.New()
	machineID := uuid.New()

	masterSignPub, masterSignPriv, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)
	masterFingerprint := crypto.HashKeyFingerprint(masterSignPub)

	machineSignPub, machineSignPriv, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)

	pushSvc := &capturingPushService{calls: make(chan pushCall, 1)}
	machineRepo := &machineRepoMock{
		findFn: func(ctx context.Context, id uuid.UUID) (domain.Machine, error) {
			return domain.Machine{
				ID:             machineID,
				MasterID:       masterID,
				MachineSignPub: machineSignPub,
			}, nil
		},
	}
	masterKeys := &masterKeyRepoMock{
		findByMasterFingerprintFn: func(ctx context.Context, id uuid.UUID, fingerprint string) (domain.MasterKey, error) {
			if fingerprint != masterFingerprint {
				return domain.MasterKey{}, repository.ErrMasterKeyNotFound
			}
			return domain.MasterKey{MasterSignPub: masterSignPub}, nil
		},
	}
	tokens := &tokenServiceMock{
		verifyConnectFn: func(ctx context.Context, token string) (ConnectTokenClaims, error) {
			return ConnectTokenClaims{MasterID: masterID, MasterSignKeyFingerprint: masterFingerprint}, nil
		},
		verifyMachineFn: func(ctx context.Context, token string) (MachineTokenClaims, error) {
			return MachineTokenClaims{MasterID: masterID, MachineID: machineID, MasterSignKeyFingerprint: masterFingerprint}, nil
		},
	}

	svc := NewWSService(machineRepo, masterKeys, tokens, NewWSHub(), NewSessionRegistry(), pushSvc, testWSServiceConfig())
	wsURL := newWSServer(t, svc)

	machineConn := dialWS(t, wsURL)
	registerMachineWS(t, machineConn, machineID, machineSignPriv, "host")

	clientConn := dialWS(t, wsURL)
	require.NoError(t, clientConn.WriteJSON(registerMessage{
		Type:         WSTypeRegister,
		Role:         WSRoleClient,
		ConnectToken: "connect",
	}))
	readJSON(t, clientConn, &registeredMessage{})

	clientEphemeral := "client-ephemeral"
	initMsg := crypto.BuildSessionInitMessage(machineID.String(), clientEphemeral)
	initSig := ed25519.Sign(masterSignPriv, []byte(initMsg))

	require.NoError(t, clientConn.WriteJSON(sessionInitMessage{
		Type:               WSTypeSessionInit,
		MachineID:          machineID.String(),
		MachineToken:       "machine",
		ClientEphemeralPub: clientEphemeral,
		Signature:          base64.StdEncoding.EncodeToString(initSig),
	}))

	var initReceived sessionInitMessage
	readJSON(t, machineConn, &initReceived)

	machineEphemeral := "machine-ephemeral"
	ackMsg := crypto.BuildSessionAckMessage(machineID.String(), machineEphemeral)
	ackSig := ed25519.Sign(machineSignPriv, []byte(ackMsg))
	require.NoError(t, machineConn.WriteJSON(sessionAckMessage{
		Type:                WSTypeSessionAck,
		MachineID:           machineID.String(),
		MachineEphemeralPub: machineEphemeral,
		Signature:           base64.StdEncoding.EncodeToString(ackSig),
	}))
	readJSON(t, clientConn, &sessionAckMessage{})

	eventMsg := encryptedMessage{
		Type:       WSTypeEvent,
		MachineID:  machineID.String(),
		MsgID:      "evt-1",
		Nonce:      "n",
		Ciphertext: "c",
		Hint:       &eventHint{Event: "run.finished"},
	}
	require.NoError(t, machineConn.WriteJSON(eventMsg))

	var eventReceived encryptedMessage
	readJSON(t, clientConn, &eventReceived)
	assert.Equal(t, eventMsg.Type, eventReceived.Type)
	assert.Equal(t, eventMsg.MachineID, eventReceived.MachineID)
	assert.Equal(t, eventMsg.MsgID, eventReceived.MsgID)
	assert.Equal(t, eventMsg.Hint.Event, eventReceived.Hint.Event)

	select {
	case call := <-pushSvc.calls:
		assert.Equal(t, masterID, call.masterID)
		assert.Equal(t, "run.finished", call.hint.Event)
	case <-time.After(time.Second):
		t.Fatal("expected push to be triggered for hinted event")
	}
}

func TestWSService_ForwardMachineEventPushesWithoutActiveSession(t *testing.T) {
	masterID := uuid.New()
	machineID := uuid.New()

	hub := NewWSHub()
	hub.machines[machineID] = &machineConn{
		ID:       machineID,
		MasterID: masterID,
		Hostname: "host",
	}

	pushSvc := &capturingPushService{calls: make(chan pushCall, 1)}
	svc := NewWSService(&machineRepoMock{}, &masterKeyRepoMock{}, &tokenServiceMock{}, hub, NewSessionRegistry(), pushSvc, testWSServiceConfig())

	raw, err := json.Marshal(encryptedMessage{
		Type:       WSTypeEvent,
		MachineID:  machineID.String(),
		MsgID:      "evt-2",
		Nonce:      "n",
		Ciphertext: "c",
		Hint:       &eventHint{Event: "run.failed"},
	})
	require.NoError(t, err)

	wsSvc, ok := svc.(*wsServiceImpl)
	require.True(t, ok)
	err = wsSvc.forwardMachineMessage(raw, machineID)
	require.ErrorIs(t, err, ErrUnauthorizedSession)

	select {
	case call := <-pushSvc.calls:
		assert.Equal(t, masterID, call.masterID)
		assert.Equal(t, "run.failed", call.hint.Event)
	case <-time.After(time.Second):
		t.Fatal("expected push to be triggered without an active session")
	}
}
