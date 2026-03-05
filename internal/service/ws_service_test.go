package service

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/LaLanMo/muxagent-relay/internal/domain"
	"github.com/LaLanMo/muxagent-relay/internal/infra/crypto"
	"github.com/LaLanMo/muxagent-relay/internal/repository"
	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type tokenServiceMock struct {
	verifyConnectFn func(ctx context.Context, token string) (ConnectTokenClaims, error)
	verifyMachineFn func(ctx context.Context, token string) (MachineTokenClaims, error)
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

type machineRepoMock struct {
	findFn   func(ctx context.Context, id uuid.UUID) (domain.Machine, error)
	updateFn func(ctx context.Context, id uuid.UUID, lastSeen time.Time, hostname string) error
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

	svc := NewWSService(machineRepo, &masterKeyRepoMock{}, tokens, NewWSHub(), NewSessionRegistry(), NewPushService(nil, NewWSHub(), nil))
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

	svc := NewWSService(machineRepo, masterKeys, tokens, NewWSHub(), NewSessionRegistry(), NewPushService(nil, NewWSHub(), nil))
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

	svc := NewWSService(machineRepo, &masterKeyRepoMock{}, tokens, NewWSHub(), NewSessionRegistry(), NewPushService(nil, NewWSHub(), nil))
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
