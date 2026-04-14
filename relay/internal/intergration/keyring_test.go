package intergration

import (
	"bytes"
	"crypto/ed25519"
	"encoding/base64"
	"net/http"
	"testing"
	"time"

	"github.com/LaLanMo/muxagent/relay/internal/api"
	"github.com/LaLanMo/muxagent/relay/internal/infra/crypto"
	"github.com/LaLanMo/muxagent/relay/internal/repository/dao"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gorm.io/gorm"
)

func TestKeyringGet_Valid(t *testing.T) {
	srv := newTestServer(t)

	masterID := uuid.New()
	require.NoError(t, srv.db.Create(&dao.MasterIdentity{
		ID:              masterID,
		CreatedAt:       time.Now(),
		KeyringSeq:      3,
		KeyringHeadHash: "head",
	}).Error)
	signPub, signPriv := generateEd25519Keypair(t)
	encPub, _ := generateX25519Keypair(t)
	require.NoError(t, srv.db.Create(&dao.MasterKey{
		ID:                       uuid.New(),
		MasterID:                 masterID,
		MasterSignKeyFingerprint: crypto.HashKeyFingerprint(signPub),
		MasterSignPub:            signPub,
		MasterEncPub:             encPub,
		CreatedAt:                time.Now(),
		KeyringSeqAdded:          1,
	}).Error)

	token := buildConnectToken(t, masterID, signPub, signPriv)
	out := fetchKeyringState(t, srv, masterID, token)
	assert.Equal(t, masterID.String(), out.MasterID)
	assert.Equal(t, 3, out.Seq)
	assert.Equal(t, "head", out.HeadHash)
	require.Len(t, out.Keys, 1)
}

func TestKeyringGet_InvalidMasterID(t *testing.T) {
	srv := newTestServer(t)

	// Send a dummy token so middleware passes the auth-header check
	// and reaches the master_id parse step.
	req, err := http.NewRequest(http.MethodGet, srv.server.URL+"/v1/keyring/not-a-uuid", nil)
	require.NoError(t, err)
	req.Header.Set("Authorization", "Bearer dummy")
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusBadRequest, resp.StatusCode)
	env := decodeEnvelope(t, resp)
	assert.Equal(t, api.CodeInvalidRequest, env.Code)
	assert.Equal(t, "invalid master_id", env.Message)
}

func TestKeyringGet_NotFound(t *testing.T) {
	srv := newTestServer(t)

	// Seed a master key (without MasterIdentity) so the connect token
	// verifies, but the handler returns 404 for the missing identity.
	masterID := uuid.New()
	signPub, signPriv := generateEd25519Keypair(t)
	encPub, _ := generateX25519Keypair(t)
	require.NoError(t, srv.db.Create(&dao.MasterKey{
		ID:                       uuid.New(),
		MasterID:                 masterID,
		MasterSignKeyFingerprint: crypto.HashKeyFingerprint(signPub),
		MasterSignPub:            signPub,
		MasterEncPub:             encPub,
		CreatedAt:                time.Now(),
		KeyringSeqAdded:          1,
	}).Error)

	token := buildConnectToken(t, masterID, signPub, signPriv)
	req, err := http.NewRequest(http.MethodGet, srv.server.URL+"/v1/keyring/"+masterID.String(), nil)
	require.NoError(t, err)
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusNotFound, resp.StatusCode)
	env := decodeEnvelope(t, resp)
	assert.Equal(t, api.CodeNotFound, env.Code)
	assert.Equal(t, "master identity not found", env.Message)
}

func TestKeyringGet_KeysSortedAndIncludesRevoked(t *testing.T) {
	srv := newTestServer(t)

	masterID := uuid.New()
	require.NoError(t, srv.db.Create(&dao.MasterIdentity{
		ID:              masterID,
		CreatedAt:       time.Now(),
		KeyringSeq:      1,
		KeyringHeadHash: "head",
	}).Error)

	signPub1, _ := generateEd25519Keypair(t)
	encPub1, _ := generateX25519Keypair(t)
	signPub2, signPriv2 := generateEd25519Keypair(t)
	encPub2, _ := generateX25519Keypair(t)

	t1 := time.Now().Add(-time.Minute)
	t2 := time.Now()
	revokedAt := time.Now().Add(-time.Hour)
	require.NoError(t, srv.db.Create(&dao.MasterKey{
		ID:                       uuid.New(),
		MasterID:                 masterID,
		MasterSignKeyFingerprint: crypto.HashKeyFingerprint(signPub1),
		MasterSignPub:            signPub1,
		MasterEncPub:             encPub1,
		CreatedAt:                t1,
		RevokedAt:                &revokedAt,
		KeyringSeqAdded:          1,
	}).Error)
	require.NoError(t, srv.db.Create(&dao.MasterKey{
		ID:                       uuid.New(),
		MasterID:                 masterID,
		MasterSignKeyFingerprint: crypto.HashKeyFingerprint(signPub2),
		MasterSignPub:            signPub2,
		MasterEncPub:             encPub2,
		CreatedAt:                t2,
		KeyringSeqAdded:          1,
	}).Error)

	token := buildConnectToken(t, masterID, signPub2, signPriv2)
	out := fetchKeyringState(t, srv, masterID, token)
	require.Len(t, out.Keys, 2)
	assert.Equal(t, crypto.HashKeyFingerprint(signPub1), out.Keys[0].MasterSignKeyFingerprint)
	assert.NotNil(t, out.Keys[0].RevokedAt)
	assert.Equal(t, crypto.HashKeyFingerprint(signPub2), out.Keys[1].MasterSignKeyFingerprint)
}

func TestKeyringGet_NoToken_Unauthorized(t *testing.T) {
	srv := newTestServer(t)
	masterID := uuid.New()
	require.NoError(t, srv.db.Create(&dao.MasterIdentity{
		ID:              masterID,
		CreatedAt:       time.Now(),
		KeyringSeq:      1,
		KeyringHeadHash: "head",
	}).Error)

	resp, err := http.Get(srv.server.URL + "/v1/keyring/" + masterID.String())
	require.NoError(t, err)
	require.Equal(t, http.StatusUnauthorized, resp.StatusCode)
}

func TestKeyringGet_WithMachineAccessToken(t *testing.T) {
	srv := newTestServer(t)
	masterID, _, _, _ := seedMasterIdentity(t, srv.db, 1, "head")

	machineSignPub, machineSignPriv := generateEd25519Keypair(t)
	machineEncPub, _ := generateX25519Keypair(t)
	machineID := uuid.New()
	require.NoError(t, srv.db.Create(&dao.Machine{
		ID:                        machineID,
		MasterID:                  masterID,
		MachineSignKeyFingerprint: crypto.HashKeyFingerprint(machineSignPub),
		MachineSignPub:            machineSignPub,
		MachineEncPub:             machineEncPub,
		Hostname:                  "test-machine",
		CreatedAt:                 time.Now(),
		LastSeenAt:                time.Now(),
	}).Error)

	token := buildMachineAccessToken(t, masterID, machineID, machineSignPub, machineSignPriv)
	out := fetchKeyringState(t, srv, masterID, token)
	assert.Equal(t, masterID.String(), out.MasterID)
	assert.Equal(t, 1, out.Seq)
	require.Len(t, out.Keys, 1)
}

func TestKeyringGet_MasterIDMismatch_Forbidden(t *testing.T) {
	srv := newTestServer(t)
	masterID, signPub, _, signPriv := seedMasterIdentity(t, srv.db, 1, "head")

	// Build token for masterID but request a different master's keyring
	otherMasterID := uuid.New()
	require.NoError(t, srv.db.Create(&dao.MasterIdentity{
		ID:              otherMasterID,
		CreatedAt:       time.Now(),
		KeyringSeq:      1,
		KeyringHeadHash: "head",
	}).Error)

	token := buildConnectToken(t, masterID, signPub, signPriv)
	req, err := http.NewRequest(http.MethodGet, srv.server.URL+"/v1/keyring/"+otherMasterID.String(), nil)
	require.NoError(t, err)
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusForbidden, resp.StatusCode)
}

func TestKeyringUpdate_ChainValidation(t *testing.T) {
	cases := []struct {
		name       string
		seq        int
		prevHash   string
		wantStatus int
		wantCode   int
		wantMsg    string
	}{
		{
			name:       "valid",
			seq:        6,
			prevHash:   "head",
			wantStatus: http.StatusOK,
		},
		{
			name:       "seq too low",
			seq:        5,
			prevHash:   "head",
			wantStatus: http.StatusConflict,
			wantCode:   api.CodeConflict,
			wantMsg:    "keyring update conflict",
		},
		{
			name:       "seq too high",
			seq:        7,
			prevHash:   "head",
			wantStatus: http.StatusConflict,
			wantCode:   api.CodeConflict,
			wantMsg:    "keyring update conflict",
		},
		{
			name:       "wrong prev hash",
			seq:        6,
			prevHash:   "wrong",
			wantStatus: http.StatusConflict,
			wantCode:   api.CodeConflict,
			wantMsg:    "keyring update conflict",
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			srv := newTestServer(t)

			masterID, signerSignPub, _, signerPriv := seedMasterIdentity(t, srv.db, 5, "head")
			targetSignPub, _ := generateEd25519Keypair(t)
			targetEncPub, _ := generateX25519Keypair(t)
			token := buildConnectToken(t, masterID, signerSignPub, signerPriv)

			input := buildKeyringUpdateInput(t, masterID, tc.seq, tc.prevHash, "add", targetSignPub, targetEncPub, signerSignPub, signerPriv)
			req := newBearerJSONRequest(http.MethodPost, srv.server.URL+"/v1/keyring/"+masterID.String()+"/update", input, token)
			resp, err := http.DefaultClient.Do(req)
			require.NoError(t, err)
			require.Equal(t, tc.wantStatus, resp.StatusCode)

			if tc.wantStatus != http.StatusOK {
				env := decodeEnvelope(t, resp)
				assert.Equal(t, tc.wantCode, env.Code)
				assert.Equal(t, tc.wantMsg, env.Message)
				var identity dao.MasterIdentity
				require.NoError(t, srv.db.First(&identity, "id = ?", masterID).Error)
				assert.Equal(t, 5, identity.KeyringSeq)
				assert.Equal(t, "head", identity.KeyringHeadHash)
				var count int64
				require.NoError(t, srv.db.Model(&dao.KeyringUpdate{}).Count(&count).Error)
				assert.Equal(t, int64(0), count)
				return
			}

			payload := crypto.KeyringUpdatePayload{
				MasterID:                       masterID.String(),
				Seq:                            tc.seq,
				PrevHash:                       tc.prevHash,
				Action:                         "add",
				TargetMasterSignPub:            input.TargetMasterSignPub,
				TargetMasterEncPub:             input.TargetMasterEncPub,
				SignerMasterSignKeyFingerprint: input.SignerMasterSignKeyFingerprint,
			}
			expectedHash := crypto.HashBytes([]byte(crypto.BuildKeyringUpdateMessage(payload)))

			var update dao.KeyringUpdate
			require.NoError(t, srv.db.First(&update, "master_id = ? AND seq = ?", masterID, tc.seq).Error)
			assert.Equal(t, expectedHash, update.UpdateHash)

			var identity dao.MasterIdentity
			require.NoError(t, srv.db.First(&identity, "id = ?", masterID).Error)
			assert.Equal(t, tc.seq, identity.KeyringSeq)
			assert.Equal(t, expectedHash, identity.KeyringHeadHash)
		})
	}
}

func TestKeyringUpdate_StaleUpdateConflict(t *testing.T) {
	srv := newTestServer(t)

	masterID, signerSignPub, _, signerPriv := seedMasterIdentity(t, srv.db, 1, "head")
	targetSignPub, _ := generateEd25519Keypair(t)
	targetEncPub, _ := generateX25519Keypair(t)
	token := buildConnectToken(t, masterID, signerSignPub, signerPriv)

	input := buildKeyringUpdateInput(t, masterID, 2, "head", "add", targetSignPub, targetEncPub, signerSignPub, signerPriv)
	req := newBearerJSONRequest(http.MethodPost, srv.server.URL+"/v1/keyring/"+masterID.String()+"/update", input, token)
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, resp.StatusCode)

	req = newBearerJSONRequest(http.MethodPost, srv.server.URL+"/v1/keyring/"+masterID.String()+"/update", input, token)
	resp, err = http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusConflict, resp.StatusCode)

	payload := crypto.KeyringUpdatePayload{
		MasterID:                       masterID.String(),
		Seq:                            input.Seq,
		PrevHash:                       input.PrevHash,
		Action:                         input.Action,
		TargetMasterSignPub:            input.TargetMasterSignPub,
		TargetMasterEncPub:             input.TargetMasterEncPub,
		SignerMasterSignKeyFingerprint: input.SignerMasterSignKeyFingerprint,
	}
	expectedHash := crypto.HashBytes([]byte(crypto.BuildKeyringUpdateMessage(payload)))

	var count int64
	require.NoError(t, srv.db.Model(&dao.KeyringUpdate{}).Count(&count).Error)
	assert.Equal(t, int64(1), count)

	var identity dao.MasterIdentity
	require.NoError(t, srv.db.First(&identity, "id = ?", masterID).Error)
	assert.Equal(t, 2, identity.KeyringSeq)
	assert.Equal(t, expectedHash, identity.KeyringHeadHash)
}

func TestKeyringUpdate_InvalidSignature(t *testing.T) {
	srv := newTestServer(t)

	masterID, signerSignPub, _, signerPriv := seedMasterIdentity(t, srv.db, 1, "head")
	targetSignPub, _ := generateEd25519Keypair(t)
	targetEncPub, _ := generateX25519Keypair(t)
	token := buildConnectToken(t, masterID, signerSignPub, signerPriv)

	input := buildKeyringUpdateInput(t, masterID, 2, "head", "add", targetSignPub, targetEncPub, signerSignPub, signerPriv)
	input.Signature = base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{7}, ed25519.SignatureSize))
	req := newBearerJSONRequest(http.MethodPost, srv.server.URL+"/v1/keyring/"+masterID.String()+"/update", input, token)
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusBadRequest, resp.StatusCode)
	env := decodeEnvelope(t, resp)
	assert.Equal(t, api.CodeInvalidSignature, env.Code)
	assert.Equal(t, "invalid keyring update signature", env.Message)
}

func TestKeyringUpdate_InvalidSignature_Decode(t *testing.T) {
	srv := newTestServer(t)

	masterID, signerSignPub, _, signerPriv := seedMasterIdentity(t, srv.db, 1, "head")
	targetSignPub, _ := generateEd25519Keypair(t)
	targetEncPub, _ := generateX25519Keypair(t)
	token := buildConnectToken(t, masterID, signerSignPub, signerPriv)
	input := buildKeyringUpdateInput(t, masterID, 2, "head", "add", targetSignPub, targetEncPub, signerSignPub, signerPriv)
	input.Signature = "!!!"
	req := newBearerJSONRequest(http.MethodPost, srv.server.URL+"/v1/keyring/"+masterID.String()+"/update", input, token)
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusBadRequest, resp.StatusCode)
	env := decodeEnvelope(t, resp)
	assert.Equal(t, api.CodeInvalidSignature, env.Code)
	assert.Equal(t, "invalid signature", env.Message)
}

func TestKeyringUpdate_SignerNotFound(t *testing.T) {
	srv := newTestServer(t)

	masterID, signerSignPub, _, signerPriv := seedMasterIdentity(t, srv.db, 1, "head")
	targetSignPub, _ := generateEd25519Keypair(t)
	targetEncPub, _ := generateX25519Keypair(t)
	token := buildConnectToken(t, masterID, signerSignPub, signerPriv)
	input := buildKeyringUpdateInput(t, masterID, 2, "head", "add", targetSignPub, targetEncPub, signerSignPub, signerPriv)
	input.SignerMasterSignKeyFingerprint = "missing"
	input.Signature = signKeyringUpdate(signerPriv, crypto.KeyringUpdatePayload{
		MasterID:                       masterID.String(),
		Seq:                            2,
		PrevHash:                       "head",
		Action:                         "add",
		TargetMasterSignPub:            input.TargetMasterSignPub,
		TargetMasterEncPub:             input.TargetMasterEncPub,
		SignerMasterSignKeyFingerprint: input.SignerMasterSignKeyFingerprint,
	})
	req := newBearerJSONRequest(http.MethodPost, srv.server.URL+"/v1/keyring/"+masterID.String()+"/update", input, token)
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusBadRequest, resp.StatusCode)
	env := decodeEnvelope(t, resp)
	assert.Equal(t, api.CodeInvalidSignature, env.Code)
	assert.Equal(t, "signer master key not found", env.Message)
}

func TestKeyringUpdate_SignerRevoked(t *testing.T) {
	srv := newTestServer(t)

	masterID, signerSignPub, _, signerPriv := seedMasterIdentity(t, srv.db, 1, "head")
	targetSignPub, _ := generateEd25519Keypair(t)
	targetEncPub, _ := generateX25519Keypair(t)

	authSignPub, authSignPriv := generateEd25519Keypair(t)
	authEncPub, _ := generateX25519Keypair(t)
	require.NoError(t, srv.db.Create(&dao.MasterKey{
		ID:                       uuid.New(),
		MasterID:                 masterID,
		MasterSignKeyFingerprint: crypto.HashKeyFingerprint(authSignPub),
		MasterSignPub:            authSignPub,
		MasterEncPub:             authEncPub,
		CreatedAt:                time.Now(),
		KeyringSeqAdded:          1,
	}).Error)
	token := buildConnectToken(t, masterID, authSignPub, authSignPriv)

	require.NoError(t, srv.db.Model(&dao.MasterKey{}).
		Where("master_id = ? AND master_sign_key_fingerprint = ?", masterID, crypto.HashKeyFingerprint(signerSignPub)).
		Update("revoked_at", time.Now()).Error)

	input := buildKeyringUpdateInput(t, masterID, 2, "head", "add", targetSignPub, targetEncPub, signerSignPub, signerPriv)
	req := newBearerJSONRequest(http.MethodPost, srv.server.URL+"/v1/keyring/"+masterID.String()+"/update", input, token)
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusBadRequest, resp.StatusCode)
	env := decodeEnvelope(t, resp)
	assert.Equal(t, api.CodeInvalidSignature, env.Code)
	assert.Equal(t, "signer master key not found", env.Message)
}

func TestKeyringUpdate_SignerDifferentMaster(t *testing.T) {
	srv := newTestServer(t)

	masterID, masterSignPub, _, masterSignPriv := seedMasterIdentity(t, srv.db, 1, "head")
	token := buildConnectToken(t, masterID, masterSignPub, masterSignPriv)

	otherID := uuid.New()
	otherSignPub, otherSignPriv := generateEd25519Keypair(t)
	otherEncPub, _ := generateX25519Keypair(t)
	require.NoError(t, srv.db.Create(&dao.MasterIdentity{
		ID:              otherID,
		CreatedAt:       time.Now(),
		KeyringSeq:      1,
		KeyringHeadHash: "head",
	}).Error)
	require.NoError(t, srv.db.Create(&dao.MasterKey{
		ID:                       uuid.New(),
		MasterID:                 otherID,
		MasterSignKeyFingerprint: crypto.HashKeyFingerprint(otherSignPub),
		MasterSignPub:            otherSignPub,
		MasterEncPub:             otherEncPub,
		CreatedAt:                time.Now(),
		KeyringSeqAdded:          1,
	}).Error)

	targetSignPub, _ := generateEd25519Keypair(t)
	targetEncPub, _ := generateX25519Keypair(t)
	input := buildKeyringUpdateInput(t, masterID, 2, "head", "add", targetSignPub, targetEncPub, otherSignPub, otherSignPriv)
	input.SignerMasterSignKeyFingerprint = crypto.HashKeyFingerprint(otherSignPub)
	input.Signature = signKeyringUpdate(otherSignPriv, crypto.KeyringUpdatePayload{
		MasterID:                       masterID.String(),
		Seq:                            2,
		PrevHash:                       "head",
		Action:                         "add",
		TargetMasterSignPub:            input.TargetMasterSignPub,
		TargetMasterEncPub:             input.TargetMasterEncPub,
		SignerMasterSignKeyFingerprint: input.SignerMasterSignKeyFingerprint,
	})

	req := newBearerJSONRequest(http.MethodPost, srv.server.URL+"/v1/keyring/"+masterID.String()+"/update", input, token)
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusBadRequest, resp.StatusCode)
	env := decodeEnvelope(t, resp)
	assert.Equal(t, api.CodeInvalidSignature, env.Code)
	assert.Equal(t, "signer master key not found", env.Message)
}

func TestKeyringUpdate_AddCases(t *testing.T) {
	cases := []struct {
		name       string
		setup      func(t *testing.T, srv *testServer, masterID uuid.UUID, targetSignPub ed25519.PublicKey, targetEncPub []byte)
		input      func(t *testing.T, masterID uuid.UUID, targetSignPub ed25519.PublicKey, targetEncPub []byte, signerSignPub ed25519.PublicKey, signerPriv ed25519.PrivateKey) keyringUpdateRequest
		wantStatus int
		wantCode   int
		wantMsg    string
		checkDB    func(t *testing.T, srv *testServer, masterID uuid.UUID, targetSignPub ed25519.PublicKey, targetEncPub []byte, input keyringUpdateRequest)
	}{
		{
			name:       "valid",
			wantStatus: http.StatusOK,
			input: func(t *testing.T, masterID uuid.UUID, targetSignPub ed25519.PublicKey, targetEncPub []byte, signerSignPub ed25519.PublicKey, signerPriv ed25519.PrivateKey) keyringUpdateRequest {
				return buildKeyringUpdateInput(t, masterID, 2, "head", "add", targetSignPub, targetEncPub, signerSignPub, signerPriv)
			},
			checkDB: func(t *testing.T, srv *testServer, masterID uuid.UUID, targetSignPub ed25519.PublicKey, targetEncPub []byte, input keyringUpdateRequest) {
				fingerprint := crypto.HashKeyFingerprint(targetSignPub)
				var masterKey dao.MasterKey
				require.NoError(t, srv.db.First(&masterKey, "master_sign_key_fingerprint = ?", fingerprint).Error)
				assert.Equal(t, masterID, masterKey.MasterID)
				assert.Equal(t, []byte(targetSignPub), masterKey.MasterSignPub)
				assert.Equal(t, targetEncPub, masterKey.MasterEncPub)

				payload := crypto.KeyringUpdatePayload{
					MasterID:                       masterID.String(),
					Seq:                            input.Seq,
					PrevHash:                       input.PrevHash,
					Action:                         input.Action,
					TargetMasterSignPub:            input.TargetMasterSignPub,
					TargetMasterEncPub:             input.TargetMasterEncPub,
					SignerMasterSignKeyFingerprint: input.SignerMasterSignKeyFingerprint,
				}
				expectedHash := crypto.HashBytes([]byte(crypto.BuildKeyringUpdateMessage(payload)))

				var update dao.KeyringUpdate
				require.NoError(t, srv.db.First(&update, "master_id = ? AND seq = ?", masterID, input.Seq).Error)
				assert.Equal(t, expectedHash, update.UpdateHash)

				var identity dao.MasterIdentity
				require.NoError(t, srv.db.First(&identity, "id = ?", masterID).Error)
				assert.Equal(t, input.Seq, identity.KeyringSeq)
				assert.Equal(t, expectedHash, identity.KeyringHeadHash)
			},
		},
		{
			name:       "missing enc pub",
			wantStatus: http.StatusBadRequest,
			wantCode:   api.CodeInvalidRequest,
			wantMsg:    "target_master_enc_pub required for add",
			input: func(t *testing.T, masterID uuid.UUID, targetSignPub ed25519.PublicKey, targetEncPub []byte, signerSignPub ed25519.PublicKey, signerPriv ed25519.PrivateKey) keyringUpdateRequest {
				return buildKeyringUpdateInput(t, masterID, 2, "head", "add", targetSignPub, nil, signerSignPub, signerPriv)
			},
		},
		{
			name:       "duplicate key",
			wantStatus: http.StatusConflict,
			wantCode:   api.CodeConflict,
			wantMsg:    "master key already exists",
			setup: func(t *testing.T, srv *testServer, masterID uuid.UUID, targetSignPub ed25519.PublicKey, targetEncPub []byte) {
				require.NoError(t, srv.db.Create(&dao.MasterKey{
					ID:                       uuid.New(),
					MasterID:                 masterID,
					MasterSignKeyFingerprint: crypto.HashKeyFingerprint(targetSignPub),
					MasterSignPub:            targetSignPub,
					MasterEncPub:             targetEncPub,
					CreatedAt:                time.Now(),
					KeyringSeqAdded:          1,
				}).Error)
			},
			input: func(t *testing.T, masterID uuid.UUID, targetSignPub ed25519.PublicKey, targetEncPub []byte, signerSignPub ed25519.PublicKey, signerPriv ed25519.PrivateKey) keyringUpdateRequest {
				return buildKeyringUpdateInput(t, masterID, 2, "head", "add", targetSignPub, targetEncPub, signerSignPub, signerPriv)
			},
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			srv := newTestServer(t)

			masterID, signerSignPub, _, signerPriv := seedMasterIdentity(t, srv.db, 1, "head")
			targetSignPub, _ := generateEd25519Keypair(t)
			targetEncPub, _ := generateX25519Keypair(t)
			token := buildConnectToken(t, masterID, signerSignPub, signerPriv)
			if tc.setup != nil {
				tc.setup(t, srv, masterID, targetSignPub, targetEncPub)
			}

			input := tc.input(t, masterID, targetSignPub, targetEncPub, signerSignPub, signerPriv)
			req := newBearerJSONRequest(http.MethodPost, srv.server.URL+"/v1/keyring/"+masterID.String()+"/update", input, token)
			resp, err := http.DefaultClient.Do(req)
			require.NoError(t, err)
			require.Equal(t, tc.wantStatus, resp.StatusCode)

			if tc.wantStatus != http.StatusOK {
				env := decodeEnvelope(t, resp)
				assert.Equal(t, tc.wantCode, env.Code)
				assert.Equal(t, tc.wantMsg, env.Message)
				var count int64
				require.NoError(t, srv.db.Model(&dao.KeyringUpdate{}).Count(&count).Error)
				assert.Equal(t, int64(0), count)
				var identity dao.MasterIdentity
				require.NoError(t, srv.db.First(&identity, "id = ?", masterID).Error)
				assert.Equal(t, 1, identity.KeyringSeq)
				return
			}

			if tc.checkDB != nil {
				tc.checkDB(t, srv, masterID, targetSignPub, targetEncPub, input)
			}
		})
	}
}

func TestKeyringUpdate_RevokeCases(t *testing.T) {
	cases := []struct {
		name       string
		setup      func(t *testing.T, srv *testServer, masterID uuid.UUID, targetSignPub ed25519.PublicKey, targetEncPub []byte) *time.Time
		input      func(t *testing.T, masterID uuid.UUID, targetSignPub ed25519.PublicKey, signerSignPub ed25519.PublicKey, signerPriv ed25519.PrivateKey) keyringUpdateRequest
		wantStatus int
		wantCode   int
		wantMsg    string
		checkDB    func(t *testing.T, srv *testServer, masterID uuid.UUID, targetSignPub ed25519.PublicKey, oldRevokedAt *time.Time, input keyringUpdateRequest)
	}{
		{
			name:       "revoke valid",
			wantStatus: http.StatusOK,
			setup: func(t *testing.T, srv *testServer, masterID uuid.UUID, targetSignPub ed25519.PublicKey, targetEncPub []byte) *time.Time {
				require.NoError(t, srv.db.Create(&dao.MasterKey{
					ID:                       uuid.New(),
					MasterID:                 masterID,
					MasterSignKeyFingerprint: crypto.HashKeyFingerprint(targetSignPub),
					MasterSignPub:            targetSignPub,
					MasterEncPub:             targetEncPub,
					CreatedAt:                time.Now(),
					KeyringSeqAdded:          1,
				}).Error)
				return nil
			},
			input: func(t *testing.T, masterID uuid.UUID, targetSignPub ed25519.PublicKey, signerSignPub ed25519.PublicKey, signerPriv ed25519.PrivateKey) keyringUpdateRequest {
				return buildKeyringUpdateInput(t, masterID, 2, "head", "revoke", targetSignPub, nil, signerSignPub, signerPriv)
			},
			checkDB: func(t *testing.T, srv *testServer, masterID uuid.UUID, targetSignPub ed25519.PublicKey, oldRevokedAt *time.Time, input keyringUpdateRequest) {
				fingerprint := crypto.HashKeyFingerprint(targetSignPub)
				var masterKey dao.MasterKey
				require.NoError(t, srv.db.First(&masterKey, "master_sign_key_fingerprint = ?", fingerprint).Error)
				require.NotNil(t, masterKey.RevokedAt)

				payload := crypto.KeyringUpdatePayload{
					MasterID:                       masterID.String(),
					Seq:                            input.Seq,
					PrevHash:                       input.PrevHash,
					Action:                         input.Action,
					TargetMasterSignPub:            input.TargetMasterSignPub,
					TargetMasterEncPub:             input.TargetMasterEncPub,
					SignerMasterSignKeyFingerprint: input.SignerMasterSignKeyFingerprint,
				}
				expectedHash := crypto.HashBytes([]byte(crypto.BuildKeyringUpdateMessage(payload)))

				var update dao.KeyringUpdate
				require.NoError(t, srv.db.First(&update, "master_id = ? AND seq = ?", masterID, input.Seq).Error)
				assert.Equal(t, expectedHash, update.UpdateHash)

				var identity dao.MasterIdentity
				require.NoError(t, srv.db.First(&identity, "id = ?", masterID).Error)
				assert.Equal(t, input.Seq, identity.KeyringSeq)
				assert.Equal(t, expectedHash, identity.KeyringHeadHash)
			},
		},
		{
			name:       "revoke already revoked",
			wantStatus: http.StatusOK,
			setup: func(t *testing.T, srv *testServer, masterID uuid.UUID, targetSignPub ed25519.PublicKey, targetEncPub []byte) *time.Time {
				old := time.Now().Add(-time.Hour)
				require.NoError(t, srv.db.Create(&dao.MasterKey{
					ID:                       uuid.New(),
					MasterID:                 masterID,
					MasterSignKeyFingerprint: crypto.HashKeyFingerprint(targetSignPub),
					MasterSignPub:            targetSignPub,
					MasterEncPub:             targetEncPub,
					CreatedAt:                time.Now(),
					KeyringSeqAdded:          1,
					RevokedAt:                &old,
				}).Error)
				return &old
			},
			input: func(t *testing.T, masterID uuid.UUID, targetSignPub ed25519.PublicKey, signerSignPub ed25519.PublicKey, signerPriv ed25519.PrivateKey) keyringUpdateRequest {
				return buildKeyringUpdateInput(t, masterID, 2, "head", "revoke", targetSignPub, nil, signerSignPub, signerPriv)
			},
			checkDB: func(t *testing.T, srv *testServer, masterID uuid.UUID, targetSignPub ed25519.PublicKey, oldRevokedAt *time.Time, input keyringUpdateRequest) {
				fingerprint := crypto.HashKeyFingerprint(targetSignPub)
				var masterKey dao.MasterKey
				require.NoError(t, srv.db.First(&masterKey, "master_sign_key_fingerprint = ?", fingerprint).Error)
				require.NotNil(t, masterKey.RevokedAt)
				if oldRevokedAt != nil {
					assert.True(t, masterKey.RevokedAt.Equal(*oldRevokedAt))
				}

				payload := crypto.KeyringUpdatePayload{
					MasterID:                       masterID.String(),
					Seq:                            input.Seq,
					PrevHash:                       input.PrevHash,
					Action:                         input.Action,
					TargetMasterSignPub:            input.TargetMasterSignPub,
					TargetMasterEncPub:             input.TargetMasterEncPub,
					SignerMasterSignKeyFingerprint: input.SignerMasterSignKeyFingerprint,
				}
				expectedHash := crypto.HashBytes([]byte(crypto.BuildKeyringUpdateMessage(payload)))

				var update dao.KeyringUpdate
				require.NoError(t, srv.db.First(&update, "master_id = ? AND seq = ?", masterID, input.Seq).Error)
				assert.Equal(t, expectedHash, update.UpdateHash)

				var identity dao.MasterIdentity
				require.NoError(t, srv.db.First(&identity, "id = ?", masterID).Error)
				assert.Equal(t, input.Seq, identity.KeyringSeq)
				assert.Equal(t, expectedHash, identity.KeyringHeadHash)
			},
		},
		{
			name:       "revoke non-existent",
			wantStatus: http.StatusBadRequest,
			wantCode:   api.CodeInvalidRequest,
			wantMsg:    "master key not found for revoke",
			setup: func(t *testing.T, srv *testServer, masterID uuid.UUID, targetSignPub ed25519.PublicKey, targetEncPub []byte) *time.Time {
				return nil
			},
			input: func(t *testing.T, masterID uuid.UUID, targetSignPub ed25519.PublicKey, signerSignPub ed25519.PublicKey, signerPriv ed25519.PrivateKey) keyringUpdateRequest {
				return buildKeyringUpdateInput(t, masterID, 2, "head", "revoke", targetSignPub, nil, signerSignPub, signerPriv)
			},
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			srv := newTestServer(t)

			masterID, signerSignPub, _, signerPriv := seedMasterIdentity(t, srv.db, 1, "head")
			targetSignPub, _ := generateEd25519Keypair(t)
			targetEncPub, _ := generateX25519Keypair(t)
			token := buildConnectToken(t, masterID, signerSignPub, signerPriv)
			oldRevokedAt := tc.setup(t, srv, masterID, targetSignPub, targetEncPub)

			input := tc.input(t, masterID, targetSignPub, signerSignPub, signerPriv)
			req := newBearerJSONRequest(http.MethodPost, srv.server.URL+"/v1/keyring/"+masterID.String()+"/update", input, token)
			resp, err := http.DefaultClient.Do(req)
			require.NoError(t, err)
			require.Equal(t, tc.wantStatus, resp.StatusCode)

			if tc.wantStatus != http.StatusOK {
				env := decodeEnvelope(t, resp)
				assert.Equal(t, tc.wantCode, env.Code)
				assert.Equal(t, tc.wantMsg, env.Message)
				var identity dao.MasterIdentity
				require.NoError(t, srv.db.First(&identity, "id = ?", masterID).Error)
				assert.Equal(t, 1, identity.KeyringSeq)
				return
			}

			if tc.checkDB != nil {
				tc.checkDB(t, srv, masterID, targetSignPub, oldRevokedAt, input)
			}
		})
	}
}

func TestKeyringUpdate_InvalidAction(t *testing.T) {
	srv := newTestServer(t)

	masterID, signerSignPub, _, signerPriv := seedMasterIdentity(t, srv.db, 1, "head")
	targetSignPub, _ := generateEd25519Keypair(t)
	targetEncPub, _ := generateX25519Keypair(t)
	token := buildConnectToken(t, masterID, signerSignPub, signerPriv)

	input := buildKeyringUpdateInput(t, masterID, 2, "head", "invalid", targetSignPub, targetEncPub, signerSignPub, signerPriv)
	req := newBearerJSONRequest(http.MethodPost, srv.server.URL+"/v1/keyring/"+masterID.String()+"/update", input, token)
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	require.Equal(t, http.StatusBadRequest, resp.StatusCode)
	env := decodeEnvelope(t, resp)
	assert.Equal(t, api.CodeInvalidRequest, env.Code)
	assert.Equal(t, "invalid action", env.Message)
}

func seedMasterIdentity(t *testing.T, dbConn *gorm.DB, seq int, headHash string) (uuid.UUID, ed25519.PublicKey, []byte, ed25519.PrivateKey) {
	t.Helper()
	masterID := uuid.New()
	signPub, signPriv := generateEd25519Keypair(t)
	encPub, _ := generateX25519Keypair(t)
	require.NoError(t, dbConn.Create(&dao.MasterIdentity{
		ID:              masterID,
		CreatedAt:       time.Now(),
		KeyringSeq:      seq,
		KeyringHeadHash: headHash,
	}).Error)
	require.NoError(t, dbConn.Create(&dao.MasterKey{
		ID:                       uuid.New(),
		MasterID:                 masterID,
		MasterSignKeyFingerprint: crypto.HashKeyFingerprint(signPub),
		MasterSignPub:            signPub,
		MasterEncPub:             encPub,
		CreatedAt:                time.Now(),
		KeyringSeqAdded:          1,
	}).Error)
	return masterID, signPub, encPub, signPriv
}

func buildKeyringUpdateInput(t *testing.T, masterID uuid.UUID, seq int, prevHash, action string, targetSignPub ed25519.PublicKey, targetEncPub []byte, signerSignPub ed25519.PublicKey, signerPriv ed25519.PrivateKey) keyringUpdateRequest {
	t.Helper()
	targetSignB64 := base64.StdEncoding.EncodeToString(targetSignPub)
	targetEncB64 := ""
	if len(targetEncPub) > 0 {
		targetEncB64 = base64.StdEncoding.EncodeToString(targetEncPub)
	}
	signerMasterSignKeyFingerprint := crypto.HashKeyFingerprint(signerSignPub)
	payload := crypto.KeyringUpdatePayload{
		MasterID:                       masterID.String(),
		Seq:                            seq,
		PrevHash:                       prevHash,
		Action:                         action,
		TargetMasterSignPub:            targetSignB64,
		TargetMasterEncPub:             targetEncB64,
		SignerMasterSignKeyFingerprint: signerMasterSignKeyFingerprint,
	}
	sig := signKeyringUpdate(signerPriv, payload)
	return keyringUpdateRequest{
		Seq:                            seq,
		PrevHash:                       prevHash,
		Action:                         action,
		TargetMasterSignPub:            targetSignB64,
		TargetMasterEncPub:             targetEncB64,
		SignerMasterSignKeyFingerprint: signerMasterSignKeyFingerprint,
		Signature:                      sig,
	}
}
