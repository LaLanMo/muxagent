package intergration

import (
	"crypto/ed25519"
	"encoding/base64"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/LaLanMo/muxagent-relay/internal/infra/crypto"
	"github.com/LaLanMo/muxagent-relay/internal/repository/dao"
	"github.com/LaLanMo/muxagent-relay/internal/service"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gorm.io/gorm"
)

type wsTestServer struct {
	server *httptest.Server
	db     *gorm.DB
}

func newWSTestServer(t *testing.T) *wsTestServer {
	t.Helper()
	gin.SetMode(gin.TestMode)
	container, err := InitTestContainer()
	require.NoError(t, err)
	t.Cleanup(container.Cleanup)

	srv := httptest.NewServer(container.Router)
	t.Cleanup(srv.Close)

	return &wsTestServer{
		server: srv,
		db:     container.DB,
	}
}

func wsURL(httpURL string) string {
	if strings.HasPrefix(httpURL, "https://") {
		return "wss://" + strings.TrimPrefix(httpURL, "https://") + "/ws"
	}
	return "ws://" + strings.TrimPrefix(httpURL, "http://") + "/ws"
}

func wsDial(t *testing.T, url string) *websocket.Conn {
	t.Helper()
	conn, _, err := websocket.DefaultDialer.Dial(url, http.Header{})
	require.NoError(t, err)
	t.Cleanup(func() { _ = conn.Close() })
	return conn
}

func wsRead(t *testing.T, conn *websocket.Conn, v any) {
	t.Helper()
	require.NoError(t, conn.SetReadDeadline(time.Now().Add(2*time.Second)))
	require.NoError(t, conn.ReadJSON(v))
}

type wsRegister struct {
	Type         string `json:"type"`
	Role         string `json:"role"`
	MachineID    string `json:"machine_id,omitempty"`
	Hostname     string `json:"hostname,omitempty"`
	ConnectToken string `json:"connect_token,omitempty"`
}

type wsChallenge struct {
	Type  string `json:"type"`
	Nonce string `json:"nonce"`
}

type wsChallengeResponse struct {
	Type      string `json:"type"`
	Signature string `json:"signature"`
}

type wsRegistered struct {
	Type      string `json:"type"`
	MasterID  string `json:"master_id,omitempty"`
	MachineID string `json:"machine_id,omitempty"`
}

type wsSessionInit struct {
	Type               string `json:"type"`
	MachineID          string `json:"machine_id"`
	MachineToken       string `json:"machine_token"`
	ClientEphemeralPub string `json:"client_ephemeral_pub"`
	Signature          string `json:"signature"`
}

type wsSessionAck struct {
	Type                string `json:"type"`
	MachineID           string `json:"machine_id"`
	MachineEphemeralPub string `json:"machine_ephemeral_pub"`
	Signature           string `json:"signature"`
}

type wsEncrypted struct {
	Type       string `json:"type"`
	MachineID  string `json:"machine_id"`
	MsgID      string `json:"msg_id"`
	Nonce      string `json:"nonce"`
	Ciphertext string `json:"ciphertext"`
}

type wsError struct {
	Type  string `json:"type"`
	Error string `json:"error"`
}

func seedMachine(t *testing.T, db *gorm.DB, machineID, masterID uuid.UUID, signPub []byte, encPub []byte) {
	t.Helper()
	require.NoError(t, db.Create(&dao.Machine{
		ID:                        machineID,
		MasterID:                  masterID,
		MachineSignKeyFingerprint: crypto.HashKeyFingerprint(signPub),
		MachineSignPub:            signPub,
		MachineEncPub:             encPub,
		Hostname:                  "test-host",
		CreatedAt:                 time.Now(),
		LastSeenAt:                time.Now(),
	}).Error)
}

func buildToken(prefix string, parts []string, priv ed25519.PrivateKey) string {
	payload := strings.Join(append([]string{prefix}, parts...), "|")
	sig := ed25519.Sign(priv, []byte(payload))
	return base64.RawURLEncoding.EncodeToString([]byte(payload)) + "." + base64.RawURLEncoding.EncodeToString(sig)
}

func TestWS_HandshakeAndRouting(t *testing.T) {
	srv := newWSTestServer(t)

	masterID, masterSignPub, _, masterSignPriv := seedMasterIdentity(t, srv.db, 1, "head")
	fingerprint := crypto.HashKeyFingerprint(masterSignPub)

	machineID := uuid.New()
	machineSignPub, machineSignPriv := generateEd25519Keypair(t)
	machineEncPub, _ := generateX25519Keypair(t)
	seedMachine(t, srv.db, machineID, masterID, machineSignPub, machineEncPub)

	expiresAt := time.Now().Add(5 * time.Minute).Unix()
	connectToken := buildToken(service.TokenPrefixConnect, []string{masterID.String(), fingerprint, strconv.FormatInt(expiresAt, 10)}, masterSignPriv)
	machineToken := buildToken(service.TokenPrefixMachine, []string{masterID.String(), machineID.String(), fingerprint, strconv.FormatInt(expiresAt, 10)}, masterSignPriv)

	wsEndpoint := wsURL(srv.server.URL)

	machineConn := wsDial(t, wsEndpoint)
	require.NoError(t, machineConn.WriteJSON(wsRegister{
		Type:      string(service.WSTypeRegister),
		Role:      string(service.WSRoleMachine),
		MachineID: machineID.String(),
		Hostname:  "host",
	}))
	var challenge wsChallenge
	wsRead(t, machineConn, &challenge)
	assert.Equal(t, string(service.WSTypeChallenge), challenge.Type)
	msg := crypto.BuildMachineAuthMessage(machineID.String(), challenge.Nonce)
	sig := ed25519.Sign(machineSignPriv, []byte(msg))
	require.NoError(t, machineConn.WriteJSON(wsChallengeResponse{
		Type:      string(service.WSTypeChallengeResponse),
		Signature: base64.StdEncoding.EncodeToString(sig),
	}))
	var machineRegistered wsRegistered
	wsRead(t, machineConn, &machineRegistered)
	assert.Equal(t, string(service.WSTypeRegistered), machineRegistered.Type)
	assert.Equal(t, machineID.String(), machineRegistered.MachineID)

	clientConn := wsDial(t, wsEndpoint)
	require.NoError(t, clientConn.WriteJSON(wsRegister{
		Type:         string(service.WSTypeRegister),
		Role:         string(service.WSRoleClient),
		ConnectToken: connectToken,
	}))
	var clientRegistered wsRegistered
	wsRead(t, clientConn, &clientRegistered)
	assert.Equal(t, string(service.WSTypeRegistered), clientRegistered.Type)
	assert.Equal(t, masterID.String(), clientRegistered.MasterID)

	clientEphemeral := "client-ephemeral"
	initPayload := crypto.BuildSessionInitMessage(machineID.String(), clientEphemeral)
	initSig := ed25519.Sign(masterSignPriv, []byte(initPayload))
	require.NoError(t, clientConn.WriteJSON(wsSessionInit{
		Type:               string(service.WSTypeSessionInit),
		MachineID:          machineID.String(),
		MachineToken:       machineToken,
		ClientEphemeralPub: clientEphemeral,
		Signature:          base64.StdEncoding.EncodeToString(initSig),
	}))

	var initReceived wsSessionInit
	wsRead(t, machineConn, &initReceived)
	assert.Equal(t, string(service.WSTypeSessionInit), initReceived.Type)
	assert.Equal(t, machineToken, initReceived.MachineToken)
	assert.Equal(t, clientEphemeral, initReceived.ClientEphemeralPub)

	machineEphemeral := "machine-ephemeral"
	ackPayload := crypto.BuildSessionAckMessage(machineID.String(), machineEphemeral)
	ackSig := ed25519.Sign(machineSignPriv, []byte(ackPayload))
	require.NoError(t, machineConn.WriteJSON(wsSessionAck{
		Type:                string(service.WSTypeSessionAck),
		MachineID:           machineID.String(),
		MachineEphemeralPub: machineEphemeral,
		Signature:           base64.StdEncoding.EncodeToString(ackSig),
	}))
	var ackReceived wsSessionAck
	wsRead(t, clientConn, &ackReceived)
	assert.Equal(t, string(service.WSTypeSessionAck), ackReceived.Type)
	assert.Equal(t, machineEphemeral, ackReceived.MachineEphemeralPub)

	rpcPayload := wsEncrypted{
		Type:       string(service.WSTypeRPC),
		MachineID:  machineID.String(),
		MsgID:      "msg-1",
		Nonce:      "nonce",
		Ciphertext: "cipher",
	}
	require.NoError(t, clientConn.WriteJSON(rpcPayload))
	var rpcReceived wsEncrypted
	wsRead(t, machineConn, &rpcReceived)
	assert.Equal(t, rpcPayload, rpcReceived)

	respPayload := wsEncrypted{
		Type:       string(service.WSTypeResponse),
		MachineID:  machineID.String(),
		MsgID:      "msg-1",
		Nonce:      "nonce",
		Ciphertext: "cipher",
	}
	require.NoError(t, machineConn.WriteJSON(respPayload))
	var respReceived wsEncrypted
	wsRead(t, clientConn, &respReceived)
	assert.Equal(t, respPayload, respReceived)

	eventPayload := wsEncrypted{
		Type:       string(service.WSTypeEvent),
		MachineID:  machineID.String(),
		MsgID:      "evt-1",
		Nonce:      "nonce",
		Ciphertext: "cipher",
	}
	require.NoError(t, machineConn.WriteJSON(eventPayload))
	var eventReceived wsEncrypted
	wsRead(t, clientConn, &eventReceived)
	assert.Equal(t, eventPayload, eventReceived)
}

func TestWS_MachineBusy(t *testing.T) {
	srv := newWSTestServer(t)

	masterID, masterSignPub, _, masterSignPriv := seedMasterIdentity(t, srv.db, 1, "head")
	fingerprint := crypto.HashKeyFingerprint(masterSignPub)

	machineID := uuid.New()
	machineSignPub, machineSignPriv := generateEd25519Keypair(t)
	machineEncPub, _ := generateX25519Keypair(t)
	seedMachine(t, srv.db, machineID, masterID, machineSignPub, machineEncPub)

	expiresAt := time.Now().Add(5 * time.Minute).Unix()
	connectToken := buildToken(service.TokenPrefixConnect, []string{masterID.String(), fingerprint, strconv.FormatInt(expiresAt, 10)}, masterSignPriv)
	machineToken := buildToken(service.TokenPrefixMachine, []string{masterID.String(), machineID.String(), fingerprint, strconv.FormatInt(expiresAt, 10)}, masterSignPriv)

	wsEndpoint := wsURL(srv.server.URL)

	machineConn := wsDial(t, wsEndpoint)
	require.NoError(t, machineConn.WriteJSON(wsRegister{
		Type:      string(service.WSTypeRegister),
		Role:      string(service.WSRoleMachine),
		MachineID: machineID.String(),
		Hostname:  "host",
	}))
	var challenge wsChallenge
	wsRead(t, machineConn, &challenge)
	msg := crypto.BuildMachineAuthMessage(machineID.String(), challenge.Nonce)
	sig := ed25519.Sign(machineSignPriv, []byte(msg))
	require.NoError(t, machineConn.WriteJSON(wsChallengeResponse{
		Type:      string(service.WSTypeChallengeResponse),
		Signature: base64.StdEncoding.EncodeToString(sig),
	}))
	wsRead(t, machineConn, &wsRegistered{})

	clientConn := wsDial(t, wsEndpoint)
	require.NoError(t, clientConn.WriteJSON(wsRegister{
		Type:         string(service.WSTypeRegister),
		Role:         string(service.WSRoleClient),
		ConnectToken: connectToken,
	}))
	wsRead(t, clientConn, &wsRegistered{})

	clientEphemeral := "client-ephemeral"
	initPayload := crypto.BuildSessionInitMessage(machineID.String(), clientEphemeral)
	initSig := ed25519.Sign(masterSignPriv, []byte(initPayload))
	require.NoError(t, clientConn.WriteJSON(wsSessionInit{
		Type:               string(service.WSTypeSessionInit),
		MachineID:          machineID.String(),
		MachineToken:       machineToken,
		ClientEphemeralPub: clientEphemeral,
		Signature:          base64.StdEncoding.EncodeToString(initSig),
	}))
	wsRead(t, machineConn, &wsSessionInit{})

	machineEphemeral := "machine-ephemeral"
	ackPayload := crypto.BuildSessionAckMessage(machineID.String(), machineEphemeral)
	ackSig := ed25519.Sign(machineSignPriv, []byte(ackPayload))
	require.NoError(t, machineConn.WriteJSON(wsSessionAck{
		Type:                string(service.WSTypeSessionAck),
		MachineID:           machineID.String(),
		MachineEphemeralPub: machineEphemeral,
		Signature:           base64.StdEncoding.EncodeToString(ackSig),
	}))
	wsRead(t, clientConn, &wsSessionAck{})

	secondClient := wsDial(t, wsEndpoint)
	require.NoError(t, secondClient.WriteJSON(wsRegister{
		Type:         string(service.WSTypeRegister),
		Role:         string(service.WSRoleClient),
		ConnectToken: connectToken,
	}))
	wsRead(t, secondClient, &wsRegistered{})

	initSig2 := ed25519.Sign(masterSignPriv, []byte(initPayload))
	require.NoError(t, secondClient.WriteJSON(wsSessionInit{
		Type:               string(service.WSTypeSessionInit),
		MachineID:          machineID.String(),
		MachineToken:       machineToken,
		ClientEphemeralPub: clientEphemeral,
		Signature:          base64.StdEncoding.EncodeToString(initSig2),
	}))

	var errMsg wsError
	wsRead(t, secondClient, &errMsg)
	require.Equal(t, string(service.WSTypeError), errMsg.Type)
	require.Equal(t, service.ErrMachineBusy.Error(), errMsg.Error)
}
