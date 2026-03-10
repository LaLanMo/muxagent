package intergration

import (
	"encoding/base64"
	"net/http"
	"testing"
	"time"

	"github.com/LaLanMo/muxagent-relay/internal/api"
	"github.com/LaLanMo/muxagent-relay/internal/infra/crypto"
	"github.com/LaLanMo/muxagent-relay/internal/repository/dao"
	"github.com/LaLanMo/muxagent-relay/internal/service"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestE2E_FirstDevicePairing(t *testing.T) {
	srv := newTestServer(t)
	var resp *http.Response
	var err error
	var env api.Envelope

	// Step 1-2: CLI creates auth request
	machineID := uuid.New()
	machineSignPub, _ := generateEd25519Keypair(t)
	machineEncPub, _ := generateX25519Keypair(t)
	reqInput := authRequestInput{
		MachineID:      machineID.String(),
		MachineSignPub: base64.StdEncoding.EncodeToString(machineSignPub),
		MachineEncPub:  base64.StdEncoding.EncodeToString(machineEncPub),
	}
	req := newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/request", reqInput)
	resp, err = http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusCreated, resp.StatusCode)
	env = decodeEnvelope(t, resp)
	out := decodeEnvelopeData[api.AuthRequestResponse](t, env)

	statusPending := fetchAuthStatus(t, srv, out.RequestID)
	authReqDomain := authRequestFromStatus(t, statusPending)

	// Step 3-4: Mobile approves with keyring update
	masterID := uuid.New()
	masterSignPub, masterSignPriv := generateEd25519Keypair(t)
	masterEncPub, _ := generateX25519Keypair(t)
	approvalInput := buildFirstMasterApprovalInput(t, &authReqDomain, masterID, masterSignPub, masterEncPub, masterSignPriv)
	req = newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/"+authReqDomain.ID.String()+"/approve", approvalInput)
	resp, err = http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, resp.StatusCode)

	// Step 5: CLI polls status
	status := fetchAuthStatus(t, srv, authReqDomain.ID.String(), out.PollToken)
	require.NotNil(t, status.Keyring)
	assert.Equal(t, 1, status.Keyring.Seq)
	assert.Len(t, status.Keyring.Keys, 1)

	// Step 6-7: verify signatures
	relayPub, err := base64.StdEncoding.DecodeString(status.RelayPubKey)
	require.NoError(t, err)
	relaySig, err := base64.StdEncoding.DecodeString(status.RelaySignature)
	require.NoError(t, err)
	serviceStatus := authStatusToService(t, status)
	payload := service.BuildAuthStatusSignaturePayload(&serviceStatus, authReqDomain.ID.String())
	assert.True(t, crypto.VerifySignature(relayPub, payload, relaySig))

	approvalSig, err := base64.StdEncoding.DecodeString(status.ApprovalSignature)
	require.NoError(t, err)
	approvalMsg := crypto.BuildApprovalMessage(authReqDomain.ID.String(),
		base64.StdEncoding.EncodeToString(authReqDomain.MachineSignPub),
		base64.StdEncoding.EncodeToString(authReqDomain.MachineEncPub),
		base64.StdEncoding.EncodeToString(authReqDomain.RelayChallenge),
		authReqDomain.ExpiresAt.Unix(),
	)
	assert.True(t, crypto.VerifySignature(masterSignPub, []byte(approvalMsg), approvalSig))
}

func TestE2E_SecondDevicePairing(t *testing.T) {
	srv := newTestServer(t)
	var resp *http.Response
	var err error
	var env api.Envelope

	// First device
	masterID := uuid.New()
	masterSignPub, masterSignPriv := generateEd25519Keypair(t)
	masterEncPub, _ := generateX25519Keypair(t)

	firstMachineID := uuid.New()
	firstSignPub, _ := generateEd25519Keypair(t)
	firstEncPub, _ := generateX25519Keypair(t)
	reqInput := authRequestInput{
		MachineID:      firstMachineID.String(),
		MachineSignPub: base64.StdEncoding.EncodeToString(firstSignPub),
		MachineEncPub:  base64.StdEncoding.EncodeToString(firstEncPub),
	}
	req := newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/request", reqInput)
	resp, err = http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusCreated, resp.StatusCode)
	env = decodeEnvelope(t, resp)
	out := decodeEnvelopeData[api.AuthRequestResponse](t, env)
	status1 := fetchAuthStatus(t, srv, out.RequestID)
	authReq1 := authRequestFromStatus(t, status1)

	approvalInput := buildFirstMasterApprovalInput(t, &authReq1, masterID, masterSignPub, masterEncPub, masterSignPriv)
	req = newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/"+authReq1.ID.String()+"/approve", approvalInput)
	resp, err = http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, resp.StatusCode)

	// Second device pairing
	secondMachineID := uuid.New()
	secondSignPub, _ := generateEd25519Keypair(t)
	secondEncPub, _ := generateX25519Keypair(t)
	reqInput = authRequestInput{
		MachineID:      secondMachineID.String(),
		MachineSignPub: base64.StdEncoding.EncodeToString(secondSignPub),
		MachineEncPub:  base64.StdEncoding.EncodeToString(secondEncPub),
	}
	req = newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/request", reqInput)
	resp, err = http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusCreated, resp.StatusCode)
	env = decodeEnvelope(t, resp)
	out = decodeEnvelopeData[api.AuthRequestResponse](t, env)
	status2 := fetchAuthStatus(t, srv, out.RequestID)
	authReq2 := authRequestFromStatus(t, status2)

	approvalSig := signApprovalMessage(masterSignPriv, authReq2.ID.String(),
		base64.StdEncoding.EncodeToString(authReq2.MachineSignPub),
		base64.StdEncoding.EncodeToString(authReq2.MachineEncPub),
		base64.StdEncoding.EncodeToString(authReq2.RelayChallenge),
		authReq2.ExpiresAt.Unix(),
	)
	approveInput2 := authApproveInput{
		MasterID:          masterID.String(),
		MasterSignPub:     base64.StdEncoding.EncodeToString(masterSignPub),
		MasterEncPub:      base64.StdEncoding.EncodeToString(masterEncPub),
		ApprovalSignature: approvalSig,
	}
	req = newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/"+authReq2.ID.String()+"/approve", approveInput2)
	resp, err = http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, resp.StatusCode)

	statusApproved := fetchAuthStatus(t, srv, authReq2.ID.String())
	assert.Equal(t, service.AuthStatusApproved, statusApproved.State)
}

func TestE2E_AddSecondMaster(t *testing.T) {
	srv := newTestServer(t)
	var resp *http.Response
	var err error
	var env api.Envelope

	// First master + identity
	masterID := uuid.New()
	masterSignPub, masterSignPriv := generateEd25519Keypair(t)
	masterEncPub, _ := generateX25519Keypair(t)
	machineID := uuid.New()
	machineSignPub, _ := generateEd25519Keypair(t)
	machineEncPub, _ := generateX25519Keypair(t)
	reqInput := authRequestInput{
		MachineID:      machineID.String(),
		MachineSignPub: base64.StdEncoding.EncodeToString(machineSignPub),
		MachineEncPub:  base64.StdEncoding.EncodeToString(machineEncPub),
	}
	req := newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/request", reqInput)
	resp, err = http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusCreated, resp.StatusCode)
	env = decodeEnvelope(t, resp)
	out := decodeEnvelopeData[api.AuthRequestResponse](t, env)
	status := fetchAuthStatus(t, srv, out.RequestID)
	authReq := authRequestFromStatus(t, status)
	approvalInput := buildFirstMasterApprovalInput(t, &authReq, masterID, masterSignPub, masterEncPub, masterSignPriv)
	req = newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/"+authReq.ID.String()+"/approve", approvalInput)
	resp, err = http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, resp.StatusCode)

	// Add second master via keyring update
	master2SignPub, master2SignPriv := generateEd25519Keypair(t)
	master2EncPub, _ := generateX25519Keypair(t)

	connectToken := buildConnectToken(t, masterID, masterSignPub, masterSignPriv)
	keyring := fetchKeyringState(t, srv, masterID, connectToken)
	updateInput := buildKeyringUpdateInput(t, masterID, keyring.Seq+1, keyring.HeadHash, "add",
		master2SignPub, master2EncPub, masterSignPub, masterSignPriv)
	req = newBearerJSONRequest(http.MethodPost, srv.server.URL+"/v1/keyring/"+masterID.String()+"/update", updateInput, connectToken)
	resp, err = http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, resp.StatusCode)

	keyringAfter := fetchKeyringState(t, srv, masterID, connectToken)
	assert.Equal(t, keyring.Seq+1, keyringAfter.Seq)
	var found bool
	for _, key := range keyringAfter.Keys {
		if key.MasterSignKeyFingerprint == crypto.HashKeyFingerprint(master2SignPub) {
			found = true
			assert.Equal(t, base64.StdEncoding.EncodeToString(master2SignPub), key.MasterSignPub)
			assert.Equal(t, base64.StdEncoding.EncodeToString(master2EncPub), key.MasterEncPub)
			assert.Nil(t, key.RevokedAt)
		}
	}
	assert.True(t, found)

	// New machine pairing can use master2
	newMachineID := uuid.New()
	newSignPub, _ := generateEd25519Keypair(t)
	newEncPub, _ := generateX25519Keypair(t)
	reqInput = authRequestInput{
		MachineID:      newMachineID.String(),
		MachineSignPub: base64.StdEncoding.EncodeToString(newSignPub),
		MachineEncPub:  base64.StdEncoding.EncodeToString(newEncPub),
	}
	req = newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/request", reqInput)
	resp, err = http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusCreated, resp.StatusCode)
	env = decodeEnvelope(t, resp)
	out = decodeEnvelopeData[api.AuthRequestResponse](t, env)
	status2 := fetchAuthStatus(t, srv, out.RequestID)
	authReq2 := authRequestFromStatus(t, status2)

	approvalSig := signApprovalMessage(master2SignPriv, authReq2.ID.String(),
		base64.StdEncoding.EncodeToString(authReq2.MachineSignPub),
		base64.StdEncoding.EncodeToString(authReq2.MachineEncPub),
		base64.StdEncoding.EncodeToString(authReq2.RelayChallenge),
		authReq2.ExpiresAt.Unix(),
	)
	approveInput := authApproveInput{
		MasterID:          masterID.String(),
		MasterSignPub:     base64.StdEncoding.EncodeToString(master2SignPub),
		MasterEncPub:      base64.StdEncoding.EncodeToString(master2EncPub),
		ApprovalSignature: approvalSig,
	}
	req = newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/"+authReq2.ID.String()+"/approve", approveInput)
	resp, err = http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, resp.StatusCode)
}

func TestE2E_RevokeMaster(t *testing.T) {
	srv := newTestServer(t)
	var resp *http.Response
	var err error
	var env api.Envelope

	masterID := uuid.New()
	masterSignPub, masterSignPriv := generateEd25519Keypair(t)
	masterEncPub, _ := generateX25519Keypair(t)
	machineID := uuid.New()
	machineSignPub, _ := generateEd25519Keypair(t)
	machineEncPub, _ := generateX25519Keypair(t)
	reqInput := authRequestInput{
		MachineID:      machineID.String(),
		MachineSignPub: base64.StdEncoding.EncodeToString(machineSignPub),
		MachineEncPub:  base64.StdEncoding.EncodeToString(machineEncPub),
	}
	req := newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/request", reqInput)
	resp, err = http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusCreated, resp.StatusCode)
	env = decodeEnvelope(t, resp)
	out := decodeEnvelopeData[api.AuthRequestResponse](t, env)
	status := fetchAuthStatus(t, srv, out.RequestID)
	authReq := authRequestFromStatus(t, status)
	approvalInput := buildFirstMasterApprovalInput(t, &authReq, masterID, masterSignPub, masterEncPub, masterSignPriv)
	req = newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/"+authReq.ID.String()+"/approve", approvalInput)
	resp, err = http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, resp.StatusCode)

	// Add second master
	master2SignPub, master2SignPriv := generateEd25519Keypair(t)
	master2EncPub, _ := generateX25519Keypair(t)
	connectToken := buildConnectToken(t, masterID, masterSignPub, masterSignPriv)
	keyring := fetchKeyringState(t, srv, masterID, connectToken)
	addInput := buildKeyringUpdateInput(t, masterID, keyring.Seq+1, keyring.HeadHash, "add",
		master2SignPub, master2EncPub, masterSignPub, masterSignPriv)
	req = newBearerJSONRequest(http.MethodPost, srv.server.URL+"/v1/keyring/"+masterID.String()+"/update", addInput, connectToken)
	resp, err = http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, resp.StatusCode)

	// Revoke master2
	keyring = fetchKeyringState(t, srv, masterID, connectToken)
	revokeInput := buildKeyringUpdateInput(t, masterID, keyring.Seq+1, keyring.HeadHash, "revoke",
		master2SignPub, nil, masterSignPub, masterSignPriv)
	req = newBearerJSONRequest(http.MethodPost, srv.server.URL+"/v1/keyring/"+masterID.String()+"/update", revokeInput, connectToken)
	resp, err = http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, resp.StatusCode)

	keyring = fetchKeyringState(t, srv, masterID, connectToken)
	var revoked bool
	for _, key := range keyring.Keys {
		if key.MasterSignKeyFingerprint == crypto.HashKeyFingerprint(master2SignPub) {
			revoked = key.RevokedAt != nil
		}
	}
	assert.True(t, revoked)

	// Approval with revoked master2 should fail
	newMachineID := uuid.New()
	newSignPub, _ := generateEd25519Keypair(t)
	newEncPub, _ := generateX25519Keypair(t)
	reqInput = authRequestInput{
		MachineID:      newMachineID.String(),
		MachineSignPub: base64.StdEncoding.EncodeToString(newSignPub),
		MachineEncPub:  base64.StdEncoding.EncodeToString(newEncPub),
	}
	req = newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/request", reqInput)
	resp, err = http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusCreated, resp.StatusCode)
	env = decodeEnvelope(t, resp)
	out = decodeEnvelopeData[api.AuthRequestResponse](t, env)
	status2 := fetchAuthStatus(t, srv, out.RequestID)
	authReq2 := authRequestFromStatus(t, status2)
	approvalSig := signApprovalMessage(master2SignPriv, authReq2.ID.String(),
		base64.StdEncoding.EncodeToString(authReq2.MachineSignPub),
		base64.StdEncoding.EncodeToString(authReq2.MachineEncPub),
		base64.StdEncoding.EncodeToString(authReq2.RelayChallenge),
		authReq2.ExpiresAt.Unix(),
	)
	approveInput := authApproveInput{
		MasterID:          masterID.String(),
		MasterSignPub:     base64.StdEncoding.EncodeToString(master2SignPub),
		MasterEncPub:      base64.StdEncoding.EncodeToString(master2EncPub),
		ApprovalSignature: approvalSig,
	}
	req = newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/"+authReq2.ID.String()+"/approve", approveInput)
	resp, err = http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusForbidden, resp.StatusCode)
	env = decodeEnvelope(t, resp)
	assert.Equal(t, api.CodeRevoked, env.Code)
	assert.Equal(t, "master key revoked", env.Message)
}

func TestAuthStatus_RemainsApprovedAfterExpiry(t *testing.T) {
	srv := newTestServer(t)
	var resp *http.Response
	var err error
	var env api.Envelope

	machineID := uuid.New()
	signPub, _ := generateEd25519Keypair(t)
	encPub, _ := generateX25519Keypair(t)
	reqInput := authRequestInput{
		MachineID:      machineID.String(),
		MachineSignPub: base64.StdEncoding.EncodeToString(signPub),
		MachineEncPub:  base64.StdEncoding.EncodeToString(encPub),
	}
	req := newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/request", reqInput)
	resp, err = http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusCreated, resp.StatusCode)
	env = decodeEnvelope(t, resp)
	out := decodeEnvelopeData[api.AuthRequestResponse](t, env)
	status := fetchAuthStatus(t, srv, out.RequestID)
	authReq := authRequestFromStatus(t, status)

	masterID := uuid.New()
	masterSignPub, masterSignPriv := generateEd25519Keypair(t)
	masterEncPub, _ := generateX25519Keypair(t)
	approvalInput := buildFirstMasterApprovalInput(t, &authReq, masterID, masterSignPub, masterEncPub, masterSignPriv)
	req = newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/"+authReq.ID.String()+"/approve", approvalInput)
	resp, err = http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, resp.StatusCode)

	// Expire request and ensure status is still approved
	require.NoError(t, srv.db.Model(&dao.AuthRequest{}).Where("id = ?", authReq.ID).
		Update("expires_at", time.Now().Add(-time.Minute)).Error)
	resp, err = http.Get(srv.server.URL + "/v1/auth/" + authReq.ID.String())
	require.NoError(t, err)
	env = decodeEnvelope(t, resp)
	status = decodeEnvelopeData[api.AuthStatusResponse](t, env)
	assert.Equal(t, service.AuthStatusApproved, status.State)
}
