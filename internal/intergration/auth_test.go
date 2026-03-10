package intergration

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"encoding/base64"
	"net/http"
	"net/url"
	"testing"
	"time"

	"github.com/LaLanMo/muxagent-relay/internal/api"
	"github.com/LaLanMo/muxagent-relay/internal/domain"
	"github.com/LaLanMo/muxagent-relay/internal/infra/crypto"
	"github.com/LaLanMo/muxagent-relay/internal/repository/dao"
	"github.com/LaLanMo/muxagent-relay/internal/service"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestAuthRequest_Valid(t *testing.T) {
	srv := newTestServer(t)

	machineID := uuid.New()
	signPub, _ := generateEd25519Keypair(t)
	encPub, _ := generateX25519Keypair(t)

	input := authRequestInput{
		MachineID:      machineID.String(),
		MachineSignPub: base64.StdEncoding.EncodeToString(signPub),
		MachineEncPub:  base64.StdEncoding.EncodeToString(encPub),
	}
	req := newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/request", input)
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusCreated, resp.StatusCode)

	env := decodeEnvelope(t, resp)
	require.Equal(t, api.CodeSuccess, env.Code)
	out := decodeEnvelopeData[api.AuthRequestResponse](t, env)

	_, err = uuid.Parse(out.RequestID)
	require.NoError(t, err)

	expectedQR := "muxagent://auth?id=" + url.QueryEscape(out.RequestID) + "&relay=" + url.QueryEscape("https://relay.test")
	require.Equal(t, expectedQR, out.QRURL)

	assert.WithinDuration(t, time.Now().Add(service.AuthRequestTTL), time.Unix(out.ExpiresAt, 0).UTC(), 5*time.Second)

	authRow := fetchAuthRequest(t, srv.db, out.RequestID)
	assert.Equal(t, machineID, authRow.MachineID)
	assert.Equal(t, []byte(signPub), authRow.MachineSignPub)
	assert.Equal(t, encPub, authRow.MachineEncPub)
	assert.WithinDuration(t, time.Unix(out.ExpiresAt, 0).UTC(), authRow.ExpiresAt, time.Second)
	assert.Nil(t, authRow.ApprovedAt)
	assert.Nil(t, authRow.ApprovedByMasterSignKeyFingerprint)
	assert.Empty(t, authRow.ApprovalSignature)
	require.Len(t, authRow.RelayChallenge, 32)
}

func TestAuthRequest_MachineAlreadyPaired(t *testing.T) {
	srv := newTestServer(t)

	machineID := uuid.New()
	masterID := uuid.New()
	signPub, _ := generateEd25519Keypair(t)
	encPub, _ := generateX25519Keypair(t)
	err := srv.db.Create(&dao.Machine{
		ID:                        machineID,
		MasterID:                  masterID,
		MachineSignKeyFingerprint: crypto.HashKeyFingerprint(signPub),
		MachineSignPub:            signPub,
		MachineEncPub:             encPub,
		CreatedAt:                 time.Now(),
		LastSeenAt:                time.Now(),
	}).Error
	require.NoError(t, err)

	input := authRequestInput{
		MachineID:      machineID.String(),
		MachineSignPub: base64.StdEncoding.EncodeToString(signPub),
		MachineEncPub:  base64.StdEncoding.EncodeToString(encPub),
	}
	req := newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/request", input)
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusCreated, resp.StatusCode)
	env := decodeEnvelope(t, resp)
	assert.Equal(t, api.CodeSuccess, env.Code)

	out := decodeEnvelopeData[api.AuthRequestResponse](t, env)
	authRow := fetchAuthRequest(t, srv.db, out.RequestID)
	assert.Equal(t, machineID, authRow.MachineID)
	assert.Equal(t, []byte(signPub), authRow.MachineSignPub)
	assert.Equal(t, encPub, authRow.MachineEncPub)

	var machine dao.Machine
	require.NoError(t, srv.db.First(&machine, "id = ?", machineID).Error)
	assert.Equal(t, machineID, machine.ID)
	assert.Equal(t, masterID, machine.MasterID)
}

func TestAuthStatus_Pending(t *testing.T) {
	srv := newTestServer(t)

	machineID := uuid.New()
	signPub, _ := generateEd25519Keypair(t)
	encPub, _ := generateX25519Keypair(t)
	authReq, err := srv.authService.CreateAuthRequest(context.Background(), machineID, signPub, encPub, "test-host")
	require.NoError(t, err)

	resp, err := http.Get(srv.server.URL + "/v1/auth/" + authReq.ID.String())
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, resp.StatusCode)
	env := decodeEnvelope(t, resp)
	out := decodeEnvelopeData[api.AuthStatusResponse](t, env)

	assert.Equal(t, service.AuthStatusPending, out.State)
	assert.Equal(t, authReq.ID.String(), out.RequestID)
	assert.Equal(t, base64.StdEncoding.EncodeToString(signPub), out.MachineSignPub)
	assert.Equal(t, base64.StdEncoding.EncodeToString(encPub), out.MachineEncPub)
	assert.Equal(t, base64.StdEncoding.EncodeToString(authReq.RelayChallenge), out.RelayChallenge)
	assert.WithinDuration(t, authReq.ExpiresAt, time.Unix(out.ExpiresAt, 0).UTC(), time.Second)
	assert.Nil(t, out.Keyring)
	assert.Empty(t, out.RelaySignature)

	authRow := fetchAuthRequest(t, srv.db, authReq.ID.String())
	assert.Nil(t, authRow.ApprovedAt)
	assert.Nil(t, authRow.ApprovedByMasterSignKeyFingerprint)
	assert.Equal(t, int64(0), countMasterIdentities(t, srv.db))
}

func TestAuthStatus_Expired(t *testing.T) {
	srv := newTestServer(t)

	machineID := uuid.New()
	signPub, _ := generateEd25519Keypair(t)
	encPub, _ := generateX25519Keypair(t)
	authReq, err := srv.authService.CreateAuthRequest(context.Background(), machineID, signPub, encPub, "test-host")
	require.NoError(t, err)

	require.NoError(t, srv.db.Model(&dao.AuthRequest{}).Where("id = ?", authReq.ID).
		Update("expires_at", time.Now().Add(-time.Second)).Error)

	resp, err := http.Get(srv.server.URL + "/v1/auth/" + authReq.ID.String())
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, resp.StatusCode)
	env := decodeEnvelope(t, resp)
	out := decodeEnvelopeData[api.AuthStatusResponse](t, env)

	assert.Equal(t, service.AuthStatusExpired, out.State)

	authRow := fetchAuthRequest(t, srv.db, authReq.ID.String())
	assert.Nil(t, authRow.ApprovedAt)
}

func TestAuthStatus_Approved(t *testing.T) {
	srv := newTestServer(t)

	machineID := uuid.New()
	signPub, _ := generateEd25519Keypair(t)
	encPub, _ := generateX25519Keypair(t)
	authReq, err := srv.authService.CreateAuthRequest(context.Background(), machineID, signPub, encPub, "test-host")
	require.NoError(t, err)

	masterID := uuid.New()
	masterSignPub, masterSignPriv := generateEd25519Keypair(t)
	masterEncPub, _ := generateX25519Keypair(t)

	approvalInput := buildFirstMasterApprovalInput(t, authReq, masterID, masterSignPub, masterEncPub, masterSignPriv)
	req := newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/"+authReq.ID.String()+"/approve", approvalInput)
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, resp.StatusCode)

	env := decodeEnvelope(t, resp)
	out := decodeEnvelopeData[api.AuthStatusResponse](t, env)
	assert.Equal(t, service.AuthStatusApproved, out.State)
	assert.NotEmpty(t, out.ApprovalSignature)
	assert.NotEmpty(t, out.RelaySignature)
	assert.NotNil(t, out.Keyring)
	assert.Equal(t, masterID.String(), out.MasterID)

	fingerprint := crypto.HashKeyFingerprint(masterSignPub)
	payload := crypto.KeyringUpdatePayload{
		MasterID:                       masterID.String(),
		Seq:                            1,
		PrevHash:                       "",
		Action:                         "add",
		TargetMasterSignPub:            base64.StdEncoding.EncodeToString(masterSignPub),
		TargetMasterEncPub:             base64.StdEncoding.EncodeToString(masterEncPub),
		SignerMasterSignKeyFingerprint: fingerprint,
	}
	updateMsg := crypto.BuildKeyringUpdateMessage(payload)
	updateHash := crypto.HashBytes([]byte(updateMsg))

	authRow := fetchAuthRequest(t, srv.db, authReq.ID.String())
	require.NotNil(t, authRow.ApprovedAt)
	require.NotNil(t, authRow.ApprovedByMasterSignKeyFingerprint)
	assert.Equal(t, fingerprint, *authRow.ApprovedByMasterSignKeyFingerprint)
	approvalSigBytes, err := base64.StdEncoding.DecodeString(approvalInput.ApprovalSignature)
	require.NoError(t, err)
	assert.Equal(t, approvalSigBytes, authRow.ApprovalSignature)

	var identity dao.MasterIdentity
	require.NoError(t, srv.db.First(&identity, "id = ?", masterID).Error)
	assert.Equal(t, 1, identity.KeyringSeq)
	assert.Equal(t, updateHash, identity.KeyringHeadHash)

	var masterKey dao.MasterKey
	require.NoError(t, srv.db.First(&masterKey, "master_sign_key_fingerprint = ?", fingerprint).Error)
	assert.Equal(t, masterID, masterKey.MasterID)
	assert.Equal(t, []byte(masterSignPub), masterKey.MasterSignPub)
	assert.Equal(t, masterEncPub, masterKey.MasterEncPub)
	require.NotNil(t, masterKey.AddedByMasterSignKeyFingerprint)
	assert.Equal(t, fingerprint, *masterKey.AddedByMasterSignKeyFingerprint)
	assert.Equal(t, 1, masterKey.KeyringSeqAdded)
	assert.Nil(t, masterKey.RevokedAt)

	var machine dao.Machine
	require.NoError(t, srv.db.First(&machine, "id = ?", machineID).Error)
	assert.Equal(t, masterID, machine.MasterID)
	assert.Equal(t, []byte(signPub), machine.MachineSignPub)
	assert.Equal(t, encPub, machine.MachineEncPub)

	var update dao.KeyringUpdate
	require.NoError(t, srv.db.First(&update, "master_id = ? AND seq = ?", masterID, 1).Error)
	assert.Equal(t, updateHash, update.UpdateHash)
	assert.Equal(t, "add", update.Action)
	assert.Equal(t, fingerprint, update.TargetMasterSignKeyFingerprint)
	assert.Equal(t, []byte(masterSignPub), update.TargetMasterSignPub)
	assert.Equal(t, masterEncPub, update.TargetMasterEncPub)
	assert.Equal(t, fingerprint, update.SignerMasterSignKeyFingerprint)
}

func TestAuthStatus_Approved_MasterKeyMissing(t *testing.T) {
	srv := newTestServer(t)

	machineID := uuid.New()
	signPub, _ := generateEd25519Keypair(t)
	encPub, _ := generateX25519Keypair(t)
	authReq, err := srv.authService.CreateAuthRequest(context.Background(), machineID, signPub, encPub, "test-host")
	require.NoError(t, err)

	masterID := uuid.New()
	masterSignPub, masterSignPriv := generateEd25519Keypair(t)
	masterEncPub, _ := generateX25519Keypair(t)

	approvalInput := buildFirstMasterApprovalInput(t, authReq, masterID, masterSignPub, masterEncPub, masterSignPriv)
	req := newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/"+authReq.ID.String()+"/approve", approvalInput)
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, resp.StatusCode)

	// Delete master key to simulate missing record.
	require.NoError(t, srv.db.Delete(&dao.MasterKey{}, "master_sign_key_fingerprint = ?", crypto.HashKeyFingerprint(masterSignPub)).Error)

	pollTokenB64 := base64.RawURLEncoding.EncodeToString(authReq.PollToken)
	out := fetchAuthStatus(t, srv, authReq.ID.String(), pollTokenB64)

	assert.Equal(t, service.AuthStatusApproved, out.State)
	assert.Empty(t, out.MasterID)
	assert.Nil(t, out.Keyring)
	assert.NotEmpty(t, out.RelaySignature)

	authRow := fetchAuthRequest(t, srv.db, authReq.ID.String())
	assert.NotNil(t, authRow.ApprovedAt)
	require.Equal(t, int64(1), countMasterIdentities(t, srv.db))
	require.Equal(t, int64(0), countMasterKeys(t, srv.db))
	require.Equal(t, int64(1), countKeyringUpdates(t, srv.db))
}

func TestAuthStatus_RelaySignatureValid(t *testing.T) {
	srv := newTestServer(t)

	machineID := uuid.New()
	signPub, _ := generateEd25519Keypair(t)
	encPub, _ := generateX25519Keypair(t)
	authReq, err := srv.authService.CreateAuthRequest(context.Background(), machineID, signPub, encPub, "test-host")
	require.NoError(t, err)

	masterID := uuid.New()
	masterSignPub, masterSignPriv := generateEd25519Keypair(t)
	masterEncPub, _ := generateX25519Keypair(t)
	approvalInput := buildFirstMasterApprovalInput(t, authReq, masterID, masterSignPub, masterEncPub, masterSignPriv)

	req := newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/"+authReq.ID.String()+"/approve", approvalInput)
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, resp.StatusCode)

	env := decodeEnvelope(t, resp)
	out := decodeEnvelopeData[api.AuthStatusResponse](t, env)

	relayPub, err := base64.StdEncoding.DecodeString(out.RelayPubKey)
	require.NoError(t, err)
	signature, err := base64.StdEncoding.DecodeString(out.RelaySignature)
	require.NoError(t, err)

	serviceStatus := authStatusToService(t, out)
	payload := service.BuildAuthStatusSignaturePayload(&serviceStatus, authReq.ID.String())
	require.True(t, crypto.VerifySignature(relayPub, payload, signature))

	authRow := fetchAuthRequest(t, srv.db, authReq.ID.String())
	assert.NotNil(t, authRow.ApprovedAt)
}

func TestAuthApprove_RequestStateValidation(t *testing.T) {
	srv := newTestServer(t)

	machineID := uuid.New()
	signPub, _ := generateEd25519Keypair(t)
	encPub, _ := generateX25519Keypair(t)
	authReq, err := srv.authService.CreateAuthRequest(context.Background(), machineID, signPub, encPub, "test-host")
	require.NoError(t, err)

	masterID := uuid.New()
	masterSignPub, masterSignPriv := generateEd25519Keypair(t)
	masterEncPub, _ := generateX25519Keypair(t)

	approvalInput := buildFirstMasterApprovalInput(t, authReq, masterID, masterSignPub, masterEncPub, masterSignPriv)

	// Expired
	require.NoError(t, srv.db.Model(&dao.AuthRequest{}).Where("id = ?", authReq.ID).
		Update("expires_at", time.Now().Add(-time.Second)).Error)
	req := newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/"+authReq.ID.String()+"/approve", approvalInput)
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusGone, resp.StatusCode)
	env := decodeEnvelope(t, resp)
	assert.Equal(t, api.CodeExpired, env.Code)
	assert.Equal(t, "auth request expired", env.Message)
	authRow := fetchAuthRequest(t, srv.db, authReq.ID.String())
	assert.Nil(t, authRow.ApprovedAt)
	assert.Equal(t, int64(0), countMasterIdentities(t, srv.db))
	assert.Equal(t, int64(0), countMasterKeys(t, srv.db))
	assert.Equal(t, int64(0), countKeyringUpdates(t, srv.db))
	assert.Equal(t, int64(0), countMachines(t, srv.db))

	// Reset expiry and rebuild signature with updated expires_at
	newExpiry := time.Now().Add(time.Minute)
	require.NoError(t, srv.db.Model(&dao.AuthRequest{}).Where("id = ?", authReq.ID).
		Update("expires_at", newExpiry).Error)
	authReq.ExpiresAt = newExpiry
	approvalInput = buildFirstMasterApprovalInput(t, authReq, masterID, masterSignPub, masterEncPub, masterSignPriv)

	// Already approved (idempotent)
	req = newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/"+authReq.ID.String()+"/approve", approvalInput)
	resp, err = http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, resp.StatusCode)
	env = decodeEnvelope(t, resp)
	assert.Equal(t, api.CodeSuccess, env.Code)
	assert.Equal(t, int64(1), countMasterIdentities(t, srv.db))
	assert.Equal(t, int64(1), countMasterKeys(t, srv.db))
	assert.Equal(t, int64(1), countKeyringUpdates(t, srv.db))
	assert.Equal(t, int64(1), countMachines(t, srv.db))

	req = newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/"+authReq.ID.String()+"/approve", approvalInput)
	resp, err = http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, resp.StatusCode)
	env = decodeEnvelope(t, resp)
	assert.Equal(t, api.CodeSuccess, env.Code)
	assert.Equal(t, int64(1), countMasterIdentities(t, srv.db))
	assert.Equal(t, int64(1), countMasterKeys(t, srv.db))
	assert.Equal(t, int64(1), countKeyringUpdates(t, srv.db))
	assert.Equal(t, int64(1), countMachines(t, srv.db))

}

func TestAuthApprove_FirstMasterValidationCases(t *testing.T) {
	// Validation-focused cases for first-master approval; each case mutates a single
	// field and asserts response + DB side effects.
	cases := []struct {
		name    string
		mutate  func(input *authApproveInput)
		status  int
		code    int
		message string
	}{
		{
			name: "MissingKeyringUpdate",
			mutate: func(input *authApproveInput) {
				input.KeyringUpdate = nil
			},
			status:  http.StatusBadRequest,
			code:    api.CodeInvalidRequest,
			message: "keyring_update required for first master",
		},
		{
			name: "MissingMasterID",
			mutate: func(input *authApproveInput) {
				input.MasterID = ""
			},
			// master_id can be omitted when keyring_update.master_id is present
			status:  http.StatusOK,
			code:    api.CodeSuccess,
			message: "success",
		},
		{
			name: "InvalidMasterID",
			mutate: func(input *authApproveInput) {
				input.MasterID = "not-a-uuid"
			},
			status:  http.StatusBadRequest,
			code:    api.CodeInvalidRequest,
			message: "invalid master_id",
		},
		{
			name: "KeyringMasterIDMissing",
			mutate: func(input *authApproveInput) {
				input.KeyringUpdate.MasterID = ""
			},
			status:  http.StatusBadRequest,
			code:    api.CodeInvalidSignature,
			message: "missing keyring_update.master_id",
		},
		{
			name: "KeyringMasterIDMismatch",
			mutate: func(input *authApproveInput) {
				input.KeyringUpdate.MasterID = uuid.New().String()
			},
			status:  http.StatusBadRequest,
			code:    api.CodeInvalidSignature,
			message: "keyring_update.master_id mismatch",
		},
		{
			name: "WrongSeq",
			mutate: func(input *authApproveInput) {
				input.KeyringUpdate.Seq = 2
			},
			status:  http.StatusBadRequest,
			code:    api.CodeInvalidSignature,
			message: "keyring_update.seq must be 1",
		},
		{
			name: "NonEmptyPrevHash",
			mutate: func(input *authApproveInput) {
				input.KeyringUpdate.PrevHash = "abc"
			},
			status:  http.StatusBadRequest,
			code:    api.CodeInvalidSignature,
			message: "keyring_update.prev_hash must be empty",
		},
		{
			name: "WrongAction",
			mutate: func(input *authApproveInput) {
				input.KeyringUpdate.Action = "revoke"
			},
			status:  http.StatusBadRequest,
			code:    api.CodeInvalidSignature,
			message: "keyring_update.action must be add",
		},
		{
			name: "TargetSignMismatch",
			mutate: func(input *authApproveInput) {
				input.KeyringUpdate.TargetMasterSignPub = base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{1}, ed25519.PublicKeySize))
			},
			status:  http.StatusBadRequest,
			code:    api.CodeInvalidSignature,
			message: "keyring_update.target_master_sign_pub mismatch",
		},
		{
			name: "TargetEncMismatch",
			mutate: func(input *authApproveInput) {
				input.KeyringUpdate.TargetMasterEncPub = base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{2}, 32))
			},
			status:  http.StatusBadRequest,
			code:    api.CodeInvalidSignature,
			message: "keyring_update.target_master_enc_pub mismatch",
		},
		{
			name: "SignerFingerprintMismatch",
			mutate: func(input *authApproveInput) {
				input.KeyringUpdate.SignerMasterSignKeyFingerprint = "mismatch"
			},
			status:  http.StatusBadRequest,
			code:    api.CodeInvalidSignature,
			message: "keyring_update.signer_master_sign_key_fingerprint mismatch",
		},
		{
			name: "InvalidKeyringSignature",
			mutate: func(input *authApproveInput) {
				input.KeyringUpdate.Signature = base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{7}, ed25519.SignatureSize))
			},
			status:  http.StatusBadRequest,
			code:    api.CodeInvalidSignature,
			message: "invalid keyring update signature",
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			srv := newTestServer(t)

			machineID := uuid.New()
			machineSignPub, _ := generateEd25519Keypair(t)
			machineEncPub, _ := generateX25519Keypair(t)
			authReq, err := srv.authService.CreateAuthRequest(context.Background(), machineID, machineSignPub, machineEncPub, "test-host")
			require.NoError(t, err)

			masterID := uuid.New()
			masterSignPub, masterSignPriv := generateEd25519Keypair(t)
			masterEncPub, _ := generateX25519Keypair(t)
			baseInput := buildFirstMasterApprovalInput(t, authReq, masterID, masterSignPub, masterEncPub, masterSignPriv)

			input := baseInput
			// deep copy keyring update to avoid cross-test mutations
			if baseInput.KeyringUpdate != nil {
				copy := *baseInput.KeyringUpdate
				input.KeyringUpdate = &copy
			}
			tc.mutate(&input)
			req := newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/"+authReq.ID.String()+"/approve", input)
			resp, err := http.DefaultClient.Do(req)
			require.NoError(t, err)
			require.Equal(t, tc.status, resp.StatusCode)
			env := decodeEnvelope(t, resp)
			assert.Equal(t, tc.code, env.Code)
			assert.Equal(t, tc.message, env.Message)

			authRow := fetchAuthRequest(t, srv.db, authReq.ID.String())
			if tc.status == http.StatusOK {
				assert.NotNil(t, authRow.ApprovedAt)
				expectedMasterID := input.MasterID
				// master_id can be omitted when keyring_update.master_id is present,
				// so fall back to that for DB assertions.
				if expectedMasterID == "" && input.KeyringUpdate != nil {
					expectedMasterID = input.KeyringUpdate.MasterID
				}
				require.NotEmpty(t, expectedMasterID)
				assert.Equal(t, int64(1), countMasterIdentities(t, srv.db))
				assert.Equal(t, int64(1), countMasterKeys(t, srv.db))
				assert.Equal(t, int64(1), countKeyringUpdates(t, srv.db))
				assert.Equal(t, int64(1), countMachines(t, srv.db))
				var identity dao.MasterIdentity
				require.NoError(t, srv.db.First(&identity, "id = ?", expectedMasterID).Error)
			} else {
				assert.Nil(t, authRow.ApprovedAt)
				assert.Equal(t, int64(0), countMasterIdentities(t, srv.db))
				assert.Equal(t, int64(0), countMasterKeys(t, srv.db))
				assert.Equal(t, int64(0), countKeyringUpdates(t, srv.db))
				assert.Equal(t, int64(0), countMachines(t, srv.db))
			}
		})
	}
}

func TestAuthApprove_FirstMaster_MasterIDExists(t *testing.T) {
	srv := newTestServer(t)

	machineID := uuid.New()
	machineSignPub, _ := generateEd25519Keypair(t)
	machineEncPub, _ := generateX25519Keypair(t)
	authReq, err := srv.authService.CreateAuthRequest(context.Background(), machineID, machineSignPub, machineEncPub, "test-host")
	require.NoError(t, err)

	masterID := uuid.New()
	require.NoError(t, srv.db.Create(&dao.MasterIdentity{
		ID:         masterID,
		CreatedAt:  time.Now(),
		KeyringSeq: 1,
	}).Error)

	masterSignPub, masterSignPriv := generateEd25519Keypair(t)
	masterEncPub, _ := generateX25519Keypair(t)
	input := buildFirstMasterApprovalInput(t, authReq, masterID, masterSignPub, masterEncPub, masterSignPriv)

	req := newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/"+authReq.ID.String()+"/approve", input)
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusConflict, resp.StatusCode)
	env := decodeEnvelope(t, resp)
	assert.Equal(t, api.CodeConflict, env.Code)
	assert.Equal(t, "master identity already exists", env.Message)

	authRow := fetchAuthRequest(t, srv.db, authReq.ID.String())
	assert.Nil(t, authRow.ApprovedAt)
	assert.Equal(t, int64(1), countMasterIdentities(t, srv.db))
	assert.Equal(t, int64(0), countMasterKeys(t, srv.db))
	assert.Equal(t, int64(0), countKeyringUpdates(t, srv.db))
	assert.Equal(t, int64(0), countMachines(t, srv.db))
}

func TestAuthApprove_FirstMaster_Valid(t *testing.T) {
	srv := newTestServer(t)

	machineID := uuid.New()
	machineSignPub, _ := generateEd25519Keypair(t)
	machineEncPub, _ := generateX25519Keypair(t)
	authReq, err := srv.authService.CreateAuthRequest(context.Background(), machineID, machineSignPub, machineEncPub, "test-host")
	require.NoError(t, err)

	masterID := uuid.New()
	masterSignPub, masterSignPriv := generateEd25519Keypair(t)
	masterEncPub, _ := generateX25519Keypair(t)
	input := buildFirstMasterApprovalInput(t, authReq, masterID, masterSignPub, masterEncPub, masterSignPriv)

	req := newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/"+authReq.ID.String()+"/approve", input)
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, resp.StatusCode)
	env := decodeEnvelope(t, resp)
	assert.Equal(t, api.CodeSuccess, env.Code)

	var identity dao.MasterIdentity
	require.NoError(t, srv.db.First(&identity, "id = ?", masterID).Error)
	var masterKey dao.MasterKey
	require.NoError(t, srv.db.First(&masterKey, "master_sign_key_fingerprint = ?", crypto.HashKeyFingerprint(masterSignPub)).Error)
	var machine dao.Machine
	require.NoError(t, srv.db.First(&machine, "id = ?", machineID).Error)

	fingerprint := crypto.HashKeyFingerprint(masterSignPub)
	payload := crypto.KeyringUpdatePayload{
		MasterID:                       masterID.String(),
		Seq:                            1,
		PrevHash:                       "",
		Action:                         "add",
		TargetMasterSignPub:            base64.StdEncoding.EncodeToString(masterSignPub),
		TargetMasterEncPub:             base64.StdEncoding.EncodeToString(masterEncPub),
		SignerMasterSignKeyFingerprint: fingerprint,
	}
	updateMsg := crypto.BuildKeyringUpdateMessage(payload)
	updateHash := crypto.HashBytes([]byte(updateMsg))

	assert.Equal(t, 1, identity.KeyringSeq)
	assert.Equal(t, updateHash, identity.KeyringHeadHash)
	assert.Equal(t, masterID, masterKey.MasterID)
	assert.Equal(t, []byte(masterSignPub), masterKey.MasterSignPub)
	assert.Equal(t, masterEncPub, masterKey.MasterEncPub)
	require.NotNil(t, masterKey.AddedByMasterSignKeyFingerprint)
	assert.Equal(t, fingerprint, *masterKey.AddedByMasterSignKeyFingerprint)

	var update dao.KeyringUpdate
	require.NoError(t, srv.db.First(&update, "master_id = ? AND seq = ?", masterID, 1).Error)
	assert.Equal(t, updateHash, update.UpdateHash)
	assert.Equal(t, "add", update.Action)
	assert.Equal(t, fingerprint, update.TargetMasterSignKeyFingerprint)

	authRow := fetchAuthRequest(t, srv.db, authReq.ID.String())
	assert.NotNil(t, authRow.ApprovedAt)
	require.NotNil(t, authRow.ApprovedByMasterSignKeyFingerprint)
	assert.Equal(t, fingerprint, *authRow.ApprovedByMasterSignKeyFingerprint)
}

func TestAuthApprove_ExistingMasterCases(t *testing.T) {
	// Existing master identity (with an existing machine) approving a new machine.
	srv := newTestServer(t)

	masterID := uuid.New()
	require.NoError(t, srv.db.Create(&dao.MasterIdentity{
		ID:              masterID,
		CreatedAt:       time.Now(),
		KeyringSeq:      1,
		KeyringHeadHash: "head",
	}).Error)

	masterSignPub, masterSignPriv := generateEd25519Keypair(t)
	masterEncPub, _ := generateX25519Keypair(t)
	masterSignKeyFingerprint := crypto.HashKeyFingerprint(masterSignPub)
	require.NoError(t, srv.db.Create(&dao.MasterKey{
		ID:                       uuid.New(),
		MasterID:                 masterID,
		MasterSignKeyFingerprint: masterSignKeyFingerprint,
		MasterSignPub:            masterSignPub,
		MasterEncPub:             masterEncPub,
		CreatedAt:                time.Now(),
		KeyringSeqAdded:          1,
	}).Error)
	existingMachineID := uuid.New()
	existingMachineSignPub, _ := generateEd25519Keypair(t)
	existingMachineEncPub, _ := generateX25519Keypair(t)
	require.NoError(t, srv.db.Create(&dao.Machine{
		ID:                        existingMachineID,
		MasterID:                  masterID,
		MachineSignKeyFingerprint: crypto.HashKeyFingerprint(existingMachineSignPub),
		MachineSignPub:            existingMachineSignPub,
		MachineEncPub:             existingMachineEncPub,
		CreatedAt:                 time.Now(),
		LastSeenAt:                time.Now(),
	}).Error)

	cases := []struct {
		name    string
		mutate  func(*authApproveInput)
		status  int
		code    int
		message string
	}{
		{
			name:   "Valid",
			mutate: func(_ *authApproveInput) {},
			status: http.StatusOK,
			code:   api.CodeSuccess,
		},
		{
			name: "MasterIDMismatch",
			mutate: func(input *authApproveInput) {
				input.MasterID = uuid.New().String()
			},
			status:  http.StatusBadRequest,
			code:    api.CodeInvalidRequest,
			message: "master_id mismatch",
		},
		{
			name: "EncPubMismatch",
			mutate: func(input *authApproveInput) {
				input.MasterEncPub = base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{9}, 32))
			},
			status:  http.StatusBadRequest,
			code:    api.CodeInvalidRequest,
			message: "master_enc_pub mismatch",
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			machineID := uuid.New()
			machineSignPub, _ := generateEd25519Keypair(t)
			machineEncPub, _ := generateX25519Keypair(t)
			authReq, err := srv.authService.CreateAuthRequest(context.Background(), machineID, machineSignPub, machineEncPub, "test-host")
			require.NoError(t, err)

			approvalSig := signApprovalMessage(masterSignPriv, authReq.ID.String(),
				base64.StdEncoding.EncodeToString(machineSignPub),
				base64.StdEncoding.EncodeToString(machineEncPub),
				base64.StdEncoding.EncodeToString(authReq.RelayChallenge),
				authReq.ExpiresAt.Unix(),
			)

			input := authApproveInput{
				MasterID:          masterID.String(),
				MasterSignPub:     base64.StdEncoding.EncodeToString(masterSignPub),
				MasterEncPub:      base64.StdEncoding.EncodeToString(masterEncPub),
				ApprovalSignature: approvalSig,
			}
			tc.mutate(&input)
			req := newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/"+authReq.ID.String()+"/approve", input)
			resp, err := http.DefaultClient.Do(req)
			require.NoError(t, err)
			require.Equal(t, tc.status, resp.StatusCode)
			env := decodeEnvelope(t, resp)
			assert.Equal(t, tc.code, env.Code)
			if tc.message != "" {
				assert.Equal(t, tc.message, env.Message)
			}

			authRow := fetchAuthRequest(t, srv.db, authReq.ID.String())
			if tc.status == http.StatusOK {
				assert.NotNil(t, authRow.ApprovedAt)
			} else {
				assert.Nil(t, authRow.ApprovedAt)
			}
			assert.Equal(t, int64(1), countMasterIdentities(t, srv.db))
			assert.Equal(t, int64(1), countMasterKeys(t, srv.db))
			assert.Equal(t, int64(0), countKeyringUpdates(t, srv.db))
			var machineCount int64
			require.NoError(t, srv.db.Model(&dao.Machine{}).Where("id = ?", machineID).Count(&machineCount).Error)
			if tc.status == http.StatusOK {
				assert.Equal(t, int64(1), machineCount)
			} else {
				assert.Equal(t, int64(0), machineCount)
			}
		})
	}
}

func TestAuthApprove_ExistingMaster_RevokedKey(t *testing.T) {
	srv := newTestServer(t)

	masterID := uuid.New()
	require.NoError(t, srv.db.Create(&dao.MasterIdentity{
		ID:              masterID,
		CreatedAt:       time.Now(),
		KeyringSeq:      1,
		KeyringHeadHash: "head",
	}).Error)

	masterSignPub, masterSignPriv := generateEd25519Keypair(t)
	masterEncPub, _ := generateX25519Keypair(t)
	masterSignKeyFingerprint := crypto.HashKeyFingerprint(masterSignPub)
	require.NoError(t, srv.db.Create(&dao.MasterKey{
		ID:                       uuid.New(),
		MasterID:                 masterID,
		MasterSignKeyFingerprint: masterSignKeyFingerprint,
		MasterSignPub:            masterSignPub,
		MasterEncPub:             masterEncPub,
		CreatedAt:                time.Now(),
		KeyringSeqAdded:          1,
	}).Error)
	existingMachineID := uuid.New()
	existingMachineSignPub, _ := generateEd25519Keypair(t)
	existingMachineEncPub, _ := generateX25519Keypair(t)
	require.NoError(t, srv.db.Create(&dao.Machine{
		ID:                        existingMachineID,
		MasterID:                  masterID,
		MachineSignKeyFingerprint: crypto.HashKeyFingerprint(existingMachineSignPub),
		MachineSignPub:            existingMachineSignPub,
		MachineEncPub:             existingMachineEncPub,
		CreatedAt:                 time.Now(),
		LastSeenAt:                time.Now(),
	}).Error)

	require.NoError(t, srv.db.Model(&dao.MasterKey{}).Where("master_sign_key_fingerprint = ?", masterSignKeyFingerprint).
		Update("revoked_at", time.Now()).Error)

	machineID := uuid.New()
	machineSignPub, _ := generateEd25519Keypair(t)
	machineEncPub, _ := generateX25519Keypair(t)
	authReq, err := srv.authService.CreateAuthRequest(context.Background(), machineID, machineSignPub, machineEncPub, "test-host")
	require.NoError(t, err)
	approvalSig := signApprovalMessage(masterSignPriv, authReq.ID.String(),
		base64.StdEncoding.EncodeToString(machineSignPub),
		base64.StdEncoding.EncodeToString(machineEncPub),
		base64.StdEncoding.EncodeToString(authReq.RelayChallenge),
		authReq.ExpiresAt.Unix(),
	)
	baseInput := authApproveInput{
		MasterID:          masterID.String(),
		MasterSignPub:     base64.StdEncoding.EncodeToString(masterSignPub),
		MasterEncPub:      base64.StdEncoding.EncodeToString(masterEncPub),
		ApprovalSignature: approvalSig,
	}
	req := newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/"+authReq.ID.String()+"/approve", baseInput)
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusForbidden, resp.StatusCode)
	env := decodeEnvelope(t, resp)
	assert.Equal(t, api.CodeRevoked, env.Code)
	assert.Equal(t, "master key revoked", env.Message)

	authRow := fetchAuthRequest(t, srv.db, authReq.ID.String())
	assert.Nil(t, authRow.ApprovedAt)
	var machineCount int64
	require.NoError(t, srv.db.Model(&dao.Machine{}).Where("id = ?", machineID).Count(&machineCount).Error)
	assert.Equal(t, int64(0), machineCount)
}

func TestAuthApprove_MachineBindingCases(t *testing.T) {
	srv := newTestServer(t)

	masterID := uuid.New()
	require.NoError(t, srv.db.Create(&dao.MasterIdentity{
		ID:              masterID,
		CreatedAt:       time.Now(),
		KeyringSeq:      1,
		KeyringHeadHash: "head",
	}).Error)

	masterSignPub, masterSignPriv := generateEd25519Keypair(t)
	masterEncPub, _ := generateX25519Keypair(t)
	masterSignKeyFingerprint := crypto.HashKeyFingerprint(masterSignPub)
	require.NoError(t, srv.db.Create(&dao.MasterKey{
		ID:                       uuid.New(),
		MasterID:                 masterID,
		MasterSignKeyFingerprint: masterSignKeyFingerprint,
		MasterSignPub:            masterSignPub,
		MasterEncPub:             masterEncPub,
		CreatedAt:                time.Now(),
		KeyringSeqAdded:          1,
	}).Error)
	existingMachineID := uuid.New()
	existingMachineSignPub, _ := generateEd25519Keypair(t)
	existingMachineEncPub, _ := generateX25519Keypair(t)
	require.NoError(t, srv.db.Create(&dao.Machine{
		ID:                        existingMachineID,
		MasterID:                  masterID,
		MachineSignKeyFingerprint: crypto.HashKeyFingerprint(existingMachineSignPub),
		MachineSignPub:            existingMachineSignPub,
		MachineEncPub:             existingMachineEncPub,
		CreatedAt:                 time.Now(),
		LastSeenAt:                time.Now(),
	}).Error)

	// Machine exists with same master -> idempotent, keys not updated
	{
		machineID := uuid.New()
		origSignPub, _ := generateEd25519Keypair(t)
		origEncPub, _ := generateX25519Keypair(t)
		require.NoError(t, srv.db.Create(&dao.Machine{
			ID:                        machineID,
			MasterID:                  masterID,
			MachineSignKeyFingerprint: crypto.HashKeyFingerprint(origSignPub),
			MachineSignPub:            origSignPub,
			MachineEncPub:             origEncPub,
			CreatedAt:                 time.Now(),
			LastSeenAt:                time.Now(),
		}).Error)

		newSignPub, _ := generateEd25519Keypair(t)
		newEncPub, _ := generateX25519Keypair(t)
		authReq, err := srv.authService.CreateAuthRequest(context.Background(), machineID, newSignPub, newEncPub, "test-host")
		require.NoError(t, err)
		approvalSig := signApprovalMessage(masterSignPriv, authReq.ID.String(),
			base64.StdEncoding.EncodeToString(newSignPub),
			base64.StdEncoding.EncodeToString(newEncPub),
			base64.StdEncoding.EncodeToString(authReq.RelayChallenge),
			authReq.ExpiresAt.Unix(),
		)
		input := authApproveInput{
			MasterID:          masterID.String(),
			MasterSignPub:     base64.StdEncoding.EncodeToString(masterSignPub),
			MasterEncPub:      base64.StdEncoding.EncodeToString(masterEncPub),
			ApprovalSignature: approvalSig,
		}

		req := newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/"+authReq.ID.String()+"/approve", input)
		resp, err := http.DefaultClient.Do(req)
		require.NoError(t, err)
		require.Equal(t, http.StatusOK, resp.StatusCode)

		var machine dao.Machine
		require.NoError(t, srv.db.First(&machine, "id = ?", machineID).Error)
		assert.Equal(t, []byte(origSignPub), machine.MachineSignPub)
		assert.Equal(t, origEncPub, machine.MachineEncPub)

		authRow := fetchAuthRequest(t, srv.db, authReq.ID.String())
		assert.NotNil(t, authRow.ApprovedAt)
	}

	// Machine bound to different master
	{
		machineID := uuid.New()
		otherMasterID := uuid.New()
		signPub, _ := generateEd25519Keypair(t)
		encPub, _ := generateX25519Keypair(t)
		require.NoError(t, srv.db.Create(&dao.Machine{
			ID:                        machineID,
			MasterID:                  otherMasterID,
			MachineSignKeyFingerprint: crypto.HashKeyFingerprint(signPub),
			MachineSignPub:            signPub,
			MachineEncPub:             encPub,
			CreatedAt:                 time.Now(),
			LastSeenAt:                time.Now(),
		}).Error)

		authReq, err := srv.authService.CreateAuthRequest(context.Background(), machineID, signPub, encPub, "test-host")
		require.NoError(t, err)
		approvalSig := signApprovalMessage(masterSignPriv, authReq.ID.String(),
			base64.StdEncoding.EncodeToString(signPub),
			base64.StdEncoding.EncodeToString(encPub),
			base64.StdEncoding.EncodeToString(authReq.RelayChallenge),
			authReq.ExpiresAt.Unix(),
		)
		input := authApproveInput{
			MasterID:          masterID.String(),
			MasterSignPub:     base64.StdEncoding.EncodeToString(masterSignPub),
			MasterEncPub:      base64.StdEncoding.EncodeToString(masterEncPub),
			ApprovalSignature: approvalSig,
		}
		req := newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/"+authReq.ID.String()+"/approve", input)
		resp, err := http.DefaultClient.Do(req)
		require.NoError(t, err)
		require.Equal(t, http.StatusConflict, resp.StatusCode)
		env := decodeEnvelope(t, resp)
		assert.Equal(t, api.CodeConflict, env.Code)
		assert.Equal(t, "machine already bound to another master", env.Message)

		authRow := fetchAuthRequest(t, srv.db, authReq.ID.String())
		assert.Nil(t, authRow.ApprovedAt)

		var machine dao.Machine
		require.NoError(t, srv.db.First(&machine, "id = ?", machineID).Error)
		assert.Equal(t, otherMasterID, machine.MasterID)
	}

	// Machine revoked
	{
		machineID := uuid.New()
		signPub, _ := generateEd25519Keypair(t)
		encPub, _ := generateX25519Keypair(t)
		now := time.Now()
		require.NoError(t, srv.db.Create(&dao.Machine{
			ID:                        machineID,
			MasterID:                  masterID,
			MachineSignKeyFingerprint: crypto.HashKeyFingerprint(signPub),
			MachineSignPub:            signPub,
			MachineEncPub:             encPub,
			CreatedAt:                 time.Now(),
			LastSeenAt:                time.Now(),
			RevokedAt:                 &now,
		}).Error)

		authReq, err := srv.authService.CreateAuthRequest(context.Background(), machineID, signPub, encPub, "test-host")
		require.NoError(t, err)
		approvalSig := signApprovalMessage(masterSignPriv, authReq.ID.String(),
			base64.StdEncoding.EncodeToString(signPub),
			base64.StdEncoding.EncodeToString(encPub),
			base64.StdEncoding.EncodeToString(authReq.RelayChallenge),
			authReq.ExpiresAt.Unix(),
		)
		input := authApproveInput{
			MasterID:          masterID.String(),
			MasterSignPub:     base64.StdEncoding.EncodeToString(masterSignPub),
			MasterEncPub:      base64.StdEncoding.EncodeToString(masterEncPub),
			ApprovalSignature: approvalSig,
		}
		req := newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/"+authReq.ID.String()+"/approve", input)
		resp, err := http.DefaultClient.Do(req)
		require.NoError(t, err)
		require.Equal(t, http.StatusBadRequest, resp.StatusCode)
		env := decodeEnvelope(t, resp)
		assert.Equal(t, api.CodeInvalidRequest, env.Code)
		assert.Equal(t, "machine revoked", env.Message)

		authRow := fetchAuthRequest(t, srv.db, authReq.ID.String())
		assert.Nil(t, authRow.ApprovedAt)
	}
}

func TestAuthApprove_AtExactExpiry(t *testing.T) {
	srv := newTestServer(t)

	machineID := uuid.New()
	machineSignPub, _ := generateEd25519Keypair(t)
	machineEncPub, _ := generateX25519Keypair(t)
	authReq, err := srv.authService.CreateAuthRequest(context.Background(), machineID, machineSignPub, machineEncPub, "test-host")
	require.NoError(t, err)

	// Set expiry very close to now; should still succeed.
	newExpiry := time.Now().Add(500 * time.Millisecond)
	require.NoError(t, srv.db.Model(&dao.AuthRequest{}).Where("id = ?", authReq.ID).
		Update("expires_at", newExpiry).Error)
	authReq.ExpiresAt = newExpiry

	masterID := uuid.New()
	masterSignPub, masterSignPriv := generateEd25519Keypair(t)
	masterEncPub, _ := generateX25519Keypair(t)
	approvalInput := buildFirstMasterApprovalInput(t, authReq, masterID, masterSignPub, masterEncPub, masterSignPriv)

	req := newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/"+authReq.ID.String()+"/approve", approvalInput)
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, resp.StatusCode)

	authRow := fetchAuthRequest(t, srv.db, authReq.ID.String())
	assert.NotNil(t, authRow.ApprovedAt)
	assert.Equal(t, int64(1), countMasterIdentities(t, srv.db))
	assert.Equal(t, int64(1), countMachines(t, srv.db))
}

func TestAuthApprove_JustBeforeExpiry(t *testing.T) {
	srv := newTestServer(t)

	machineID := uuid.New()
	machineSignPub, _ := generateEd25519Keypair(t)
	machineEncPub, _ := generateX25519Keypair(t)
	authReq, err := srv.authService.CreateAuthRequest(context.Background(), machineID, machineSignPub, machineEncPub, "test-host")
	require.NoError(t, err)

	newExpiry := time.Now().Add(100 * time.Millisecond)
	require.NoError(t, srv.db.Model(&dao.AuthRequest{}).Where("id = ?", authReq.ID).
		Update("expires_at", newExpiry).Error)
	authReq.ExpiresAt = newExpiry

	masterID := uuid.New()
	masterSignPub, masterSignPriv := generateEd25519Keypair(t)
	masterEncPub, _ := generateX25519Keypair(t)
	approvalInput := buildFirstMasterApprovalInput(t, authReq, masterID, masterSignPub, masterEncPub, masterSignPriv)

	req := newJSONRequest(http.MethodPost, srv.server.URL+"/v1/auth/"+authReq.ID.String()+"/approve", approvalInput)
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, resp.StatusCode)

	authRow := fetchAuthRequest(t, srv.db, authReq.ID.String())
	assert.NotNil(t, authRow.ApprovedAt)
	assert.Equal(t, int64(1), countMasterIdentities(t, srv.db))
	assert.Equal(t, int64(1), countMachines(t, srv.db))
}

func TestAuthStatus_JustExpired(t *testing.T) {
	srv := newTestServer(t)

	machineID := uuid.New()
	signPub, _ := generateEd25519Keypair(t)
	encPub, _ := generateX25519Keypair(t)
	authReq, err := srv.authService.CreateAuthRequest(context.Background(), machineID, signPub, encPub, "test-host")
	require.NoError(t, err)

	require.NoError(t, srv.db.Model(&dao.AuthRequest{}).Where("id = ?", authReq.ID).
		Update("expires_at", time.Now().Add(-time.Millisecond)).Error)

	resp, err := http.Get(srv.server.URL + "/v1/auth/" + authReq.ID.String())
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, resp.StatusCode)
	env := decodeEnvelope(t, resp)
	out := decodeEnvelopeData[api.AuthStatusResponse](t, env)
	assert.Equal(t, service.AuthStatusExpired, out.State)

	authRow := fetchAuthRequest(t, srv.db, authReq.ID.String())
	assert.Nil(t, authRow.ApprovedAt)
}

func buildFirstMasterApprovalInput(t *testing.T, authReq *domain.AuthRequest, masterID uuid.UUID, masterSignPub ed25519.PublicKey, masterEncPub []byte, masterSignPriv ed25519.PrivateKey) authApproveInput {
	t.Helper()
	approvalSig := signApprovalMessage(masterSignPriv, authReq.ID.String(),
		base64.StdEncoding.EncodeToString(authReq.MachineSignPub),
		base64.StdEncoding.EncodeToString(authReq.MachineEncPub),
		base64.StdEncoding.EncodeToString(authReq.RelayChallenge),
		authReq.ExpiresAt.Unix(),
	)

	signerMasterSignKeyFingerprint := crypto.HashKeyFingerprint(masterSignPub)
	updatePayload := crypto.KeyringUpdatePayload{
		MasterID:                       masterID.String(),
		Seq:                            1,
		PrevHash:                       "",
		Action:                         "add",
		TargetMasterSignPub:            base64.StdEncoding.EncodeToString(masterSignPub),
		TargetMasterEncPub:             base64.StdEncoding.EncodeToString(masterEncPub),
		SignerMasterSignKeyFingerprint: signerMasterSignKeyFingerprint,
	}
	updateSig := signKeyringUpdate(masterSignPriv, updatePayload)

	return authApproveInput{
		MasterID:          masterID.String(),
		MasterSignPub:     base64.StdEncoding.EncodeToString(masterSignPub),
		MasterEncPub:      base64.StdEncoding.EncodeToString(masterEncPub),
		ApprovalSignature: approvalSig,
		KeyringUpdate: &keyringUpdateInput{
			MasterID:                       updatePayload.MasterID,
			Seq:                            updatePayload.Seq,
			PrevHash:                       updatePayload.PrevHash,
			Action:                         updatePayload.Action,
			TargetMasterSignPub:            updatePayload.TargetMasterSignPub,
			TargetMasterEncPub:             updatePayload.TargetMasterEncPub,
			SignerMasterSignKeyFingerprint: updatePayload.SignerMasterSignKeyFingerprint,
			Signature:                      updateSig,
		},
	}
}
