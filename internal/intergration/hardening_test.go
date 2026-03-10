package intergration

import (
	"encoding/base64"
	"net/http"
	"strings"
	"testing"

	"github.com/LaLanMo/muxagent-relay/internal/api"
	"github.com/LaLanMo/muxagent-relay/internal/service"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestKeyringUpdate_NoToken_Unauthorized(t *testing.T) {
	srv := newTestServer(t)

	masterID, signerSignPub, _, signerPriv := seedMasterIdentity(t, srv.db, 1, "head")
	targetSignPub, _ := generateEd25519Keypair(t)
	targetEncPub, _ := generateX25519Keypair(t)

	input := buildKeyringUpdateInput(t, masterID, 2, "head", "add", targetSignPub, targetEncPub, signerSignPub, signerPriv)
	req := newJSONRequest(http.MethodPost, srv.server.URL+"/v1/keyring/"+masterID.String()+"/update", input)
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusUnauthorized, resp.StatusCode)

	env := decodeEnvelope(t, resp)
	assert.Equal(t, api.CodeUnauthorized, env.Code)
}

func TestKeyringUpdate_MasterIDMismatch_Forbidden(t *testing.T) {
	srv := newTestServer(t)

	tokenMasterID, tokenSignPub, _, tokenSignPriv := seedMasterIdentity(t, srv.db, 1, "head")
	otherMasterID, _, _, _ := seedMasterIdentity(t, srv.db, 1, "head")
	token := buildConnectToken(t, tokenMasterID, tokenSignPub, tokenSignPriv)

	req := newBearerJSONRequest(http.MethodPost, srv.server.URL+"/v1/keyring/"+otherMasterID.String()+"/update", map[string]any{}, token)
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusForbidden, resp.StatusCode)

	env := decodeEnvelope(t, resp)
	assert.Equal(t, api.CodeUnauthorized, env.Code)
}

func TestAuthRequest_HostnameTooLong(t *testing.T) {
	srv := newTestServer(t)

	machineID := uuid.New()
	machineSignPub, _ := generateEd25519Keypair(t)
	machineEncPub, _ := generateX25519Keypair(t)
	req := newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/request", authRequestInput{
		MachineID:      machineID.String(),
		MachineSignPub: base64.StdEncoding.EncodeToString(machineSignPub),
		MachineEncPub:  base64.StdEncoding.EncodeToString(machineEncPub),
		Hostname:       strings.Repeat("a", service.MaxHostnameBytes+1),
	})
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusBadRequest, resp.StatusCode)

	env := decodeEnvelope(t, resp)
	assert.Equal(t, api.CodeInvalidRequest, env.Code)
	assert.Equal(t, "hostname too long", env.Message)
}

func TestRESTBodyLimit_TooLargeReturns413(t *testing.T) {
	srv := newTestServer(t)
	oversized := strings.Repeat("a", 70*1024)

	masterID, signerSignPub, _, signerPriv := seedMasterIdentity(t, srv.db, 1, "head")
	keyringToken := buildConnectToken(t, masterID, signerSignPub, signerPriv)

	cases := []struct {
		name string
		req  *http.Request
	}{
		{
			name: "auth request",
			req: newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/request", map[string]any{
				"machine_id":       uuid.NewString(),
				"machine_sign_pub": oversized,
				"machine_enc_pub":  oversized,
			}),
		},
		{
			name: "auth approve",
			req: newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/"+uuid.NewString()+"/approve", map[string]any{
				"master_sign_pub": oversized,
			}),
		},
		{
			name: "keyring update",
			req: newBearerJSONRequest(http.MethodPost, srv.server.URL+"/v1/keyring/"+masterID.String()+"/update", map[string]any{
				"signature": oversized,
			}, keyringToken),
		},
		{
			name: "device token",
			req: newJSONRequest(http.MethodPut, srv.server.URL+"/v1/device/token", map[string]any{
				"connect_token": "token",
				"fcm_token":     oversized,
				"platform":      "ios",
			}),
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			resp, err := http.DefaultClient.Do(tc.req)
			require.NoError(t, err)
			require.Equal(t, http.StatusRequestEntityTooLarge, resp.StatusCode)

			env := decodeEnvelope(t, resp)
			assert.Equal(t, api.CodeInvalidRequest, env.Code)
			assert.Equal(t, "request body too large", env.Message)
		})
	}
}
