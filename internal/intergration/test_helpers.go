package intergration

import (
	"bytes"
	"crypto/ecdh"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/LaLanMo/muxagent-relay/internal/api"
	"github.com/LaLanMo/muxagent-relay/internal/domain"
	"github.com/LaLanMo/muxagent-relay/internal/infra/crypto"
	"github.com/LaLanMo/muxagent-relay/internal/repository/dao"
	"github.com/LaLanMo/muxagent-relay/internal/service"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
	"gorm.io/gorm"
)

type testServer struct {
	server         *localServer
	db             *gorm.DB
	authService    service.AuthService
	keyringService service.KeyringService
	relayPriv      ed25519.PrivateKey
	relayPub       ed25519.PublicKey
}

type localServer struct {
	URL string
}

type localRoundTripper struct {
	handler http.Handler
}

func (rt *localRoundTripper) RoundTrip(req *http.Request) (*http.Response, error) {
	if req.RequestURI == "" {
		req.RequestURI = req.URL.RequestURI()
	}
	rr := httptest.NewRecorder()
	rt.handler.ServeHTTP(rr, req)
	return rr.Result(), nil
}

func newTestServer(t *testing.T) *testServer {
	t.Helper()
	gin.SetMode(gin.TestMode)
	container, err := InitTestContainer()
	require.NoError(t, err)
	t.Cleanup(container.Cleanup)
	oldTransport := http.DefaultTransport
	http.DefaultTransport = &localRoundTripper{handler: container.Router}
	t.Cleanup(func() {
		http.DefaultTransport = oldTransport
	})

	return &testServer{
		server:         &localServer{URL: "http://local.test"},
		db:             container.DB,
		authService:    container.AuthService,
		keyringService: container.KeyringService,
		relayPriv:      container.RelayPriv,
		relayPub:       container.RelayPub,
	}
}

func generateEd25519Keypair(t *testing.T) (ed25519.PublicKey, ed25519.PrivateKey) {
	t.Helper()
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)
	return pub, priv
}

func generateX25519Keypair(t *testing.T) ([]byte, []byte) {
	t.Helper()
	priv, err := ecdh.X25519().GenerateKey(rand.Reader)
	require.NoError(t, err)
	return priv.PublicKey().Bytes(), priv.Bytes()
}

func signApprovalMessage(privateKey ed25519.PrivateKey, requestID, machineSignPubB64, machineEncPubB64, relayChallengeB64 string, expiresAt int64) string {
	msg := crypto.BuildApprovalMessage(requestID, machineSignPubB64, machineEncPubB64, relayChallengeB64, expiresAt)
	sig := ed25519.Sign(privateKey, []byte(msg))
	return base64.StdEncoding.EncodeToString(sig)
}

func signKeyringUpdate(privateKey ed25519.PrivateKey, payload crypto.KeyringUpdatePayload) string {
	msg := crypto.BuildKeyringUpdateMessage(payload)
	sig := ed25519.Sign(privateKey, []byte(msg))
	return base64.StdEncoding.EncodeToString(sig)
}

func buildConnectToken(t *testing.T, masterID uuid.UUID, signPub ed25519.PublicKey, signPriv ed25519.PrivateKey) string {
	t.Helper()
	fingerprint := crypto.HashKeyFingerprint(signPub)
	expiresAt := time.Now().Add(5 * time.Minute).Unix()
	payload := fmt.Sprintf("muxagent-connect-token-v1|%s|%s|%d", masterID.String(), fingerprint, expiresAt)
	sig := ed25519.Sign(signPriv, []byte(payload))
	return base64.RawURLEncoding.EncodeToString([]byte(payload)) + "." + base64.RawURLEncoding.EncodeToString(sig)
}

func buildMachineAccessToken(t *testing.T, masterID, machineID uuid.UUID, machineSignPub ed25519.PublicKey, machineSignPriv ed25519.PrivateKey) string {
	t.Helper()
	fingerprint := crypto.HashKeyFingerprint(machineSignPub)
	expiresAt := time.Now().Add(5 * time.Minute).Unix()
	payload := fmt.Sprintf("muxagent-machine-access-v1|%s|%s|%s|%d", masterID.String(), machineID.String(), fingerprint, expiresAt)
	sig := ed25519.Sign(machineSignPriv, []byte(payload))
	return base64.RawURLEncoding.EncodeToString([]byte(payload)) + "." + base64.RawURLEncoding.EncodeToString(sig)
}

func newJSONRequest(method, url string, body interface{}) *http.Request {
	var buf bytes.Buffer
	_ = json.NewEncoder(&buf).Encode(body)
	req, _ := http.NewRequest(method, url, &buf)
	req.Header.Set("Content-Type", "application/json")
	return req
}

func decodeEnvelope(t *testing.T, resp *http.Response) api.Envelope {
	t.Helper()
	defer resp.Body.Close()
	var env api.Envelope
	err := json.NewDecoder(resp.Body).Decode(&env)
	require.NoError(t, err)
	return env
}

func decodeEnvelopeData[T any](t *testing.T, env api.Envelope) T {
	t.Helper()
	raw, err := json.Marshal(env.Data)
	require.NoError(t, err)
	var out T
	require.NoError(t, json.Unmarshal(raw, &out))
	return out
}

func fetchAuthStatus(t *testing.T, srv *testServer, requestID string, pollToken ...string) api.AuthStatusResponse {
	t.Helper()
	req, err := http.NewRequest(http.MethodGet, srv.server.URL+"/v1/auth/"+requestID, nil)
	require.NoError(t, err)
	if len(pollToken) > 0 && pollToken[0] != "" {
		req.Header.Set("Authorization", "Bearer "+pollToken[0])
	}
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, resp.StatusCode)
	env := decodeEnvelope(t, resp)
	return decodeEnvelopeData[api.AuthStatusResponse](t, env)
}

func authRequestFromStatus(t *testing.T, status api.AuthStatusResponse) domain.AuthRequest {
	t.Helper()
	id, err := uuid.Parse(status.RequestID)
	require.NoError(t, err)
	machineSignPub, err := base64.StdEncoding.DecodeString(status.MachineSignPub)
	require.NoError(t, err)
	machineEncPub, err := base64.StdEncoding.DecodeString(status.MachineEncPub)
	require.NoError(t, err)
	relayChallenge, err := base64.StdEncoding.DecodeString(status.RelayChallenge)
	require.NoError(t, err)
	return domain.AuthRequest{
		ID:             id,
		MachineSignPub: machineSignPub,
		MachineEncPub:  machineEncPub,
		Hostname:       status.MachineHostname,
		RelayChallenge: relayChallenge,
		ExpiresAt:      time.Unix(status.ExpiresAt, 0).UTC(),
	}
}

func fetchKeyringState(t *testing.T, srv *testServer, masterID uuid.UUID, accessToken string) api.KeyringStateResponse {
	t.Helper()
	req, err := http.NewRequest(http.MethodGet, srv.server.URL+"/v1/keyring/"+masterID.String(), nil)
	require.NoError(t, err)
	req.Header.Set("Authorization", "Bearer "+accessToken)
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, resp.StatusCode)
	env := decodeEnvelope(t, resp)
	return decodeEnvelopeData[api.KeyringStateResponse](t, env)
}

func authStatusToService(t *testing.T, status api.AuthStatusResponse) service.AuthStatus {
	t.Helper()
	out := service.AuthStatus{
		State:                              status.State,
		RequestID:                          status.RequestID,
		MachineID:                          status.MachineID,
		MachineSignPub:                     status.MachineSignPub,
		MachineEncPub:                      status.MachineEncPub,
		MachineHostname:                    status.MachineHostname,
		RelayChallenge:                     status.RelayChallenge,
		ExpiresAt:                          time.Unix(status.ExpiresAt, 0).UTC(),
		ApprovedByMasterSignKeyFingerprint: status.ApprovedByMasterSignKeyFingerprint,
		ApprovalSignature:                  status.ApprovalSignature,
		MasterID:                           status.MasterID,
		RelayPubKey:                        status.RelayPubKey,
		RelaySignature:                     status.RelaySignature,
	}
	if status.ApprovedAt != nil {
		v := time.Unix(*status.ApprovedAt, 0).UTC()
		out.ApprovedAt = &v
	}
	if status.Keyring != nil {
		kr := service.KeyringState{
			MasterID: status.Keyring.MasterID,
			Seq:      status.Keyring.Seq,
			HeadHash: status.Keyring.HeadHash,
			Keys:     make([]service.MasterKeyState, 0, len(status.Keyring.Keys)),
		}
		for _, key := range status.Keyring.Keys {
			var revokedAt *time.Time
			if key.RevokedAt != nil {
				v := time.Unix(*key.RevokedAt, 0).UTC()
				revokedAt = &v
			}
			kr.Keys = append(kr.Keys, service.MasterKeyState{
				MasterSignKeyFingerprint: key.MasterSignKeyFingerprint,
				MasterSignPub:            key.MasterSignPub,
				MasterEncPub:             key.MasterEncPub,
				RevokedAt:                revokedAt,
			})
		}
		out.Keyring = &kr
	}
	return out
}

func fetchAuthRequest(t *testing.T, db *gorm.DB, id string) dao.AuthRequest {
	t.Helper()
	var authReq dao.AuthRequest
	require.NoError(t, db.First(&authReq, "id = ?", id).Error)
	return authReq
}

func countMasterIdentities(t *testing.T, db *gorm.DB) int64 {
	t.Helper()
	var count int64
	require.NoError(t, db.Model(&dao.MasterIdentity{}).Count(&count).Error)
	return count
}

func countMasterKeys(t *testing.T, db *gorm.DB) int64 {
	t.Helper()
	var count int64
	require.NoError(t, db.Model(&dao.MasterKey{}).Count(&count).Error)
	return count
}

func countMachines(t *testing.T, db *gorm.DB) int64 {
	t.Helper()
	var count int64
	require.NoError(t, db.Model(&dao.Machine{}).Count(&count).Error)
	return count
}

func countKeyringUpdates(t *testing.T, db *gorm.DB) int64 {
	t.Helper()
	var count int64
	require.NoError(t, db.Model(&dao.KeyringUpdate{}).Count(&count).Error)
	return count
}
