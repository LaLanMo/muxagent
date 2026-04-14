package service

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"testing"
	"time"

	"github.com/LaLanMo/muxagent/relay/internal/domain"
	"github.com/LaLanMo/muxagent/relay/internal/infra/crypto"
	"github.com/LaLanMo/muxagent/relay/internal/logging"
	"github.com/LaLanMo/muxagent/relay/internal/repository"
	"github.com/LaLanMo/muxagent/relay/internal/testutil"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type authRequestRepoMock struct {
	createFn        func(ctx context.Context, req *domain.AuthRequest) error
	findByIDFn      func(ctx context.Context, id uuid.UUID) (domain.AuthRequest, error)
	findByIDForTxFn func(ctx context.Context, id uuid.UUID) (domain.AuthRequest, error)
	updateFn        func(ctx context.Context, req *domain.AuthRequest) error
	deleteByIDFn    func(ctx context.Context, id uuid.UUID) error
	deleteExpiredFn func(ctx context.Context, cutoff time.Time) error
}

func (m *authRequestRepoMock) Create(ctx context.Context, req *domain.AuthRequest) error {
	if m.createFn != nil {
		return m.createFn(ctx, req)
	}
	return nil
}

func (m *authRequestRepoMock) FindByID(ctx context.Context, id uuid.UUID) (domain.AuthRequest, error) {
	if m.findByIDFn != nil {
		return m.findByIDFn(ctx, id)
	}
	return domain.AuthRequest{}, repository.ErrAuthRequestNotFound
}

func (m *authRequestRepoMock) FindByIDForUpdate(ctx context.Context, id uuid.UUID) (domain.AuthRequest, error) {
	if m.findByIDForTxFn != nil {
		return m.findByIDForTxFn(ctx, id)
	}
	return domain.AuthRequest{}, repository.ErrAuthRequestNotFound
}

func (m *authRequestRepoMock) Update(ctx context.Context, req *domain.AuthRequest) error {
	if m.updateFn != nil {
		return m.updateFn(ctx, req)
	}
	return nil
}

func (m *authRequestRepoMock) DeleteByID(ctx context.Context, id uuid.UUID) error {
	if m.deleteByIDFn != nil {
		return m.deleteByIDFn(ctx, id)
	}
	return nil
}

func (m *authRequestRepoMock) DeleteExpired(ctx context.Context, cutoff time.Time) error {
	if m.deleteExpiredFn != nil {
		return m.deleteExpiredFn(ctx, cutoff)
	}
	return nil
}

func (m *authRequestRepoMock) NullifyExpiredPollTokens(ctx context.Context, cutoff time.Time) error {
	return nil
}

type masterKeyRepoMock struct {
	findByFingerprintFn       func(ctx context.Context, fingerprint string) (domain.MasterKey, error)
	findByMasterFingerprintFn func(ctx context.Context, masterID uuid.UUID, fingerprint string) (domain.MasterKey, error)
	listByMasterIDFn          func(ctx context.Context, masterID uuid.UUID) ([]domain.MasterKey, error)
}

func (m *masterKeyRepoMock) Create(ctx context.Context, key *domain.MasterKey) error {
	return nil
}

func (m *masterKeyRepoMock) FindByFingerprint(ctx context.Context, fingerprint string) (domain.MasterKey, error) {
	if m.findByFingerprintFn != nil {
		return m.findByFingerprintFn(ctx, fingerprint)
	}
	return domain.MasterKey{}, repository.ErrMasterKeyNotFound
}

func (m *masterKeyRepoMock) FindByMasterAndFingerprint(ctx context.Context, masterID uuid.UUID, fingerprint string) (domain.MasterKey, error) {
	if m.findByMasterFingerprintFn != nil {
		return m.findByMasterFingerprintFn(ctx, masterID, fingerprint)
	}
	return domain.MasterKey{}, repository.ErrMasterKeyNotFound
}

func (m *masterKeyRepoMock) ListByMasterID(ctx context.Context, masterID uuid.UUID) ([]domain.MasterKey, error) {
	if m.listByMasterIDFn != nil {
		return m.listByMasterIDFn(ctx, masterID)
	}
	return nil, nil
}

func (m *masterKeyRepoMock) Revoke(ctx context.Context, masterID uuid.UUID, fingerprint string, revokedAt time.Time) error {
	return nil
}

type masterIdentityRepoMock struct {
	findByIDFn      func(ctx context.Context, id uuid.UUID) (domain.MasterIdentity, error)
	updateKeyringFn func(ctx context.Context, id uuid.UUID, seq int, headHash string) error
}

func (m *masterIdentityRepoMock) Create(ctx context.Context, identity *domain.MasterIdentity) error {
	return nil
}

func (m *masterIdentityRepoMock) FindByID(ctx context.Context, id uuid.UUID) (domain.MasterIdentity, error) {
	if m.findByIDFn != nil {
		return m.findByIDFn(ctx, id)
	}
	return domain.MasterIdentity{}, repository.ErrMasterIdentityNotFound
}

func (m *masterIdentityRepoMock) FindByIDForUpdate(ctx context.Context, id uuid.UUID) (domain.MasterIdentity, error) {
	return m.FindByID(ctx, id)
}

func (m *masterIdentityRepoMock) UpdateKeyringState(ctx context.Context, id uuid.UUID, seq int, headHash string) error {
	if m.updateKeyringFn != nil {
		return m.updateKeyringFn(ctx, id, seq, headHash)
	}
	return nil
}

type noopMachineRepo struct{}

func (n noopMachineRepo) Create(ctx context.Context, machine *domain.Machine) error { return nil }
func (n noopMachineRepo) FindByID(ctx context.Context, id uuid.UUID) (domain.Machine, error) {
	return domain.Machine{}, repository.ErrMachineNotFound
}
func (n noopMachineRepo) UpdateLastSeenAndHostname(ctx context.Context, id uuid.UUID, lastSeen time.Time, hostname string) error {
	return nil
}

type noopKeyringUpdateRepo struct{}

func (n noopKeyringUpdateRepo) Create(ctx context.Context, update *domain.KeyringUpdate) error {
	return nil
}

func (n noopKeyringUpdateRepo) ListByMasterIDFromSeq(ctx context.Context, masterID uuid.UUID, fromSeq int, limit int) ([]domain.KeyringUpdate, error) {
	return nil, nil
}

type noopTxRunner struct{}

func (n noopTxRunner) InTx(ctx context.Context, fn func(repos repository.TxRepositories) error) error {
	return fn(repository.TxRepositories{})
}

func TestAuthService_GetAuthStatus(t *testing.T) {
	relayPub, relayPriv, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)

	now := time.Now()
	requestID := uuid.New()
	machineID := uuid.New()
	masterID := uuid.New()
	masterSignPub, _, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)
	masterFingerprint := crypto.HashKeyFingerprint(masterSignPub)

	testPollToken := make([]byte, 32)
	_, err = rand.Read(testPollToken)
	require.NoError(t, err)

	tests := []struct {
		name         string
		authReq      domain.AuthRequest
		authErr      error
		pollToken    []byte
		masterKey    domain.MasterKey
		masterKeyErr error
		identity     domain.MasterIdentity
		identityErr  error
		keys         []domain.MasterKey
		keysErr      error
		wantState    AuthStatusState
		wantMasterID string
		wantKeyring  bool
		wantErr      error
	}{
		{
			name:    "not found",
			authErr: repository.ErrAuthRequestNotFound,
			wantErr: ErrAuthRequestNotFound,
		},
		{
			name: "pending",
			authReq: domain.AuthRequest{
				ID:        requestID,
				MachineID: machineID,
				ExpiresAt: now.Add(1 * time.Minute),
			},
			wantState: AuthStatusPending,
		},
		{
			name: "expired",
			authReq: domain.AuthRequest{
				ID:        requestID,
				MachineID: machineID,
				ExpiresAt: now.Add(-1 * time.Minute),
			},
			wantState: AuthStatusExpired,
		},
		{
			name: "approved with keyring",
			authReq: domain.AuthRequest{
				ID:                                 requestID,
				MachineID:                          machineID,
				ExpiresAt:                          now.Add(1 * time.Minute),
				PollToken:                          testPollToken,
				ApprovedAt:                         ptrTime(now.Add(-1 * time.Minute)),
				ApprovedByMasterSignKeyFingerprint: ptrString(masterFingerprint),
				ApprovalSignature:                  []byte("sig"),
			},
			pollToken: testPollToken,
			masterKey: domain.MasterKey{
				MasterID:                 masterID,
				MasterSignKeyFingerprint: masterFingerprint,
				MasterSignPub:            masterSignPub,
				MasterEncPub:             []byte("enc"),
			},
			identity: domain.MasterIdentity{
				ID:              masterID,
				KeyringSeq:      1,
				KeyringHeadHash: "head",
			},
			keys: []domain.MasterKey{
				{
					MasterSignKeyFingerprint: masterFingerprint,
					MasterSignPub:            masterSignPub,
					MasterEncPub:             []byte("enc"),
				},
			},
			wantState:    AuthStatusApproved,
			wantMasterID: masterID.String(),
			wantKeyring:  true,
		},
		{
			name: "approved without master key",
			authReq: domain.AuthRequest{
				ID:                                 requestID,
				MachineID:                          machineID,
				ExpiresAt:                          now.Add(1 * time.Minute),
				PollToken:                          testPollToken,
				ApprovedAt:                         ptrTime(now.Add(-1 * time.Minute)),
				ApprovedByMasterSignKeyFingerprint: ptrString(masterFingerprint),
				ApprovalSignature:                  []byte("sig"),
			},
			pollToken:    testPollToken,
			masterKeyErr: repository.ErrMasterKeyNotFound,
			wantState:    AuthStatusApproved,
		},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			authRepo := &authRequestRepoMock{
				findByIDFn: func(ctx context.Context, id uuid.UUID) (domain.AuthRequest, error) {
					if tt.authErr != nil {
						return domain.AuthRequest{}, tt.authErr
					}
					return tt.authReq, nil
				},
			}
			masterKeyRepo := &masterKeyRepoMock{
				findByFingerprintFn: func(ctx context.Context, fingerprint string) (domain.MasterKey, error) {
					if tt.masterKeyErr != nil {
						return domain.MasterKey{}, tt.masterKeyErr
					}
					return tt.masterKey, nil
				},
				listByMasterIDFn: func(ctx context.Context, masterID uuid.UUID) ([]domain.MasterKey, error) {
					if tt.keysErr != nil {
						return nil, tt.keysErr
					}
					return tt.keys, nil
				},
			}
			masterIdentityRepo := &masterIdentityRepoMock{
				findByIDFn: func(ctx context.Context, id uuid.UUID) (domain.MasterIdentity, error) {
					if tt.identityErr != nil {
						return domain.MasterIdentity{}, tt.identityErr
					}
					return tt.identity, nil
				},
			}

			svc := &AuthServiceImpl{
				authRequests:     authRepo,
				masterKeys:       masterKeyRepo,
				masterIdentities: masterIdentityRepo,
				machines:         noopMachineRepo{},
				keyringUpdates:   noopKeyringUpdateRepo{},
				txRunner:         noopTxRunner{},
				relaySignPriv:    relayPriv,
				relaySignPub:     relayPub,
			}

			status, err := svc.GetAuthStatus(context.Background(), requestID, tt.pollToken)
			if tt.wantErr != nil {
				require.Error(t, err)
				assert.ErrorIs(t, err, tt.wantErr)
				return
			}
			require.NoError(t, err)
			assert.Equal(t, tt.wantState, status.State)
			if tt.wantMasterID != "" {
				assert.Equal(t, tt.wantMasterID, status.MasterID)
			}
			if tt.wantKeyring {
				require.NotNil(t, status.Keyring)
			}

			if status.State == AuthStatusApproved {
				relayPubBytes, err := base64.StdEncoding.DecodeString(status.RelayPubKey)
				require.NoError(t, err)
				sig, err := base64.StdEncoding.DecodeString(status.RelaySignature)
				require.NoError(t, err)
				payload := BuildAuthStatusSignaturePayload(status, requestID.String())
				assert.True(t, crypto.VerifySignature(relayPubBytes, payload, sig))
			}
		})
	}
}

func TestAuthService_GetAuthStatus_PollTokenGating(t *testing.T) {
	relayPub, relayPriv, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)

	now := time.Now()
	requestID := uuid.New()
	machineID := uuid.New()
	masterID := uuid.New()
	masterSignPub, _, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)
	masterFingerprint := crypto.HashKeyFingerprint(masterSignPub)

	correctPollToken := make([]byte, 32)
	_, err = rand.Read(correctPollToken)
	require.NoError(t, err)

	wrongPollToken := make([]byte, 32)
	_, err = rand.Read(wrongPollToken)
	require.NoError(t, err)

	baseAuthReq := domain.AuthRequest{
		ID:                                 requestID,
		MachineID:                          machineID,
		MachineSignPub:                     []byte("sign"),
		MachineEncPub:                      []byte("enc"),
		ExpiresAt:                          now.Add(5 * time.Minute),
		PollToken:                          correctPollToken,
		ApprovedAt:                         ptrTime(now.Add(-1 * time.Minute)),
		ApprovedByMasterSignKeyFingerprint: ptrString(masterFingerprint),
		ApprovalSignature:                  []byte("sig"),
	}

	tests := []struct {
		name         string
		authReq      domain.AuthRequest
		pollToken    []byte
		wantStripped bool
	}{
		{
			name:         "correct poll token - full response",
			authReq:      baseAuthReq,
			pollToken:    correctPollToken,
			wantStripped: false,
		},
		{
			name:         "no poll token - stripped",
			authReq:      baseAuthReq,
			pollToken:    nil,
			wantStripped: true,
		},
		{
			name:         "wrong poll token - stripped",
			authReq:      baseAuthReq,
			pollToken:    wrongPollToken,
			wantStripped: true,
		},
		{
			name: "correct poll token but expired - stripped",
			authReq: func() domain.AuthRequest {
				r := baseAuthReq
				r.ExpiresAt = now.Add(-1 * time.Minute)
				return r
			}(),
			pollToken:    correctPollToken,
			wantStripped: true,
		},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			authRepo := &authRequestRepoMock{
				findByIDFn: func(ctx context.Context, id uuid.UUID) (domain.AuthRequest, error) {
					return tt.authReq, nil
				},
			}
			masterKeyRepo := &masterKeyRepoMock{
				findByFingerprintFn: func(ctx context.Context, fingerprint string) (domain.MasterKey, error) {
					return domain.MasterKey{
						MasterID:                 masterID,
						MasterSignKeyFingerprint: masterFingerprint,
						MasterSignPub:            masterSignPub,
						MasterEncPub:             []byte("enc"),
					}, nil
				},
				listByMasterIDFn: func(ctx context.Context, id uuid.UUID) ([]domain.MasterKey, error) {
					return []domain.MasterKey{{
						MasterSignKeyFingerprint: masterFingerprint,
						MasterSignPub:            masterSignPub,
						MasterEncPub:             []byte("enc"),
					}}, nil
				},
			}
			masterIdentityRepo := &masterIdentityRepoMock{
				findByIDFn: func(ctx context.Context, id uuid.UUID) (domain.MasterIdentity, error) {
					return domain.MasterIdentity{
						ID:              masterID,
						KeyringSeq:      1,
						KeyringHeadHash: "head",
					}, nil
				},
			}

			svc := &AuthServiceImpl{
				authRequests:     authRepo,
				masterKeys:       masterKeyRepo,
				masterIdentities: masterIdentityRepo,
				machines:         noopMachineRepo{},
				keyringUpdates:   noopKeyringUpdateRepo{},
				txRunner:         noopTxRunner{},
				relaySignPriv:    relayPriv,
				relaySignPub:     relayPub,
			}

			status, err := svc.GetAuthStatus(context.Background(), requestID, tt.pollToken)
			require.NoError(t, err)
			assert.Equal(t, AuthStatusApproved, status.State)

			if tt.wantStripped {
				assert.Empty(t, status.MasterID)
				assert.Nil(t, status.Keyring)
				assert.Empty(t, status.RelayPubKey)
				assert.Empty(t, status.RelaySignature)
				assert.Empty(t, status.ApprovalSignature)
				assert.Empty(t, status.ApprovedByMasterSignKeyFingerprint)
			} else {
				assert.Equal(t, masterID.String(), status.MasterID)
				require.NotNil(t, status.Keyring)
				assert.NotEmpty(t, status.RelayPubKey)
				assert.NotEmpty(t, status.RelaySignature)
				assert.NotEmpty(t, status.ApprovalSignature)
				assert.NotEmpty(t, status.ApprovedByMasterSignKeyFingerprint)
			}
		})
	}
}

func TestAuthService_ApproveAuthRequest_ExistingMasterEncPubMismatch(t *testing.T) {
	buf := testutil.CaptureSlog(t)

	relayPub, relayPriv, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)

	requestID := uuid.New()
	machineID := uuid.New()
	masterID := uuid.New()

	machineSignPub, _, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)
	authReq := domain.AuthRequest{
		ID:             requestID,
		MachineID:      machineID,
		MachineSignPub: machineSignPub,
		MachineEncPub:  randomBytes(t, 32),
		ExpiresAt:      time.Now().Add(5 * time.Minute),
		RelayChallenge: randomBytes(t, 32),
	}

	masterSignPub, masterSignPriv, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)
	storedMasterEncPub := randomBytes(t, 32)
	inputMasterEncPub := flippedBytes(storedMasterEncPub)
	masterFingerprint := crypto.HashKeyFingerprint(masterSignPub)

	authRepo := &authRequestRepoMock{
		findByIDForTxFn: func(ctx context.Context, id uuid.UUID) (domain.AuthRequest, error) {
			require.Equal(t, requestID, id)
			return authReq, nil
		},
	}
	masterKeyRepo := &masterKeyRepoMock{
		findByFingerprintFn: func(ctx context.Context, fingerprint string) (domain.MasterKey, error) {
			require.Equal(t, masterFingerprint, fingerprint)
			return domain.MasterKey{
				MasterID:                 masterID,
				MasterSignKeyFingerprint: masterFingerprint,
				MasterSignPub:            masterSignPub,
				MasterEncPub:             storedMasterEncPub,
			}, nil
		},
	}

	svc := &AuthServiceImpl{
		machines:       noopMachineRepo{},
		keyringUpdates: noopKeyringUpdateRepo{},
		txRunner: txRunnerMock{repos: repository.TxRepositories{
			AuthRequests:   authRepo,
			MasterKeys:     masterKeyRepo,
			Machines:       noopMachineRepo{},
			KeyringUpdates: noopKeyringUpdateRepo{},
		}},
		relaySignPriv: relayPriv,
		relaySignPub:  relayPub,
	}

	ctx := logging.WithClientIP(context.Background(), "198.51.100.21")
	status, err := svc.ApproveAuthRequest(ctx, requestID, AuthApproveInput{
		MasterSignPub:     masterSignPub,
		MasterEncPub:      inputMasterEncPub,
		ApprovalSignature: signApproval(t, authReq, masterSignPriv),
	})
	require.ErrorIs(t, err, ErrMasterEncPubMismatch)
	assert.Nil(t, status)

	entry := testutil.FindEntryByEvent(testutil.ParseLogEntries(t, buf), logging.EventAuthRequestRejected)
	require.NotNil(t, entry)
	assert.Equal(t, logging.ResultRejected, entry["result"])
	assert.Equal(t, ErrMasterEncPubMismatch.Error(), entry["reason"])
	assert.Equal(t, requestID.String(), entry["auth_request_id"])
	assert.Equal(t, machineID.String(), entry["machine_id"])
	assert.Equal(t, masterID.String(), entry["master_id"])
	assert.Equal(t, masterFingerprint, entry["master_sign_key_fingerprint"])
	assert.Equal(t, "198.51.100.21", entry["client_ip"])
	assert.NotContains(t, buf.String(), base64.StdEncoding.EncodeToString(inputMasterEncPub))
}

func TestAuthService_ApproveAuthRequest_InitialKeyringTargetMasterEncMismatch(t *testing.T) {
	relayPub, relayPriv, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)

	requestID := uuid.New()
	masterID := uuid.New()

	machineSignPub, _, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)
	authReq := domain.AuthRequest{
		ID:             requestID,
		MachineID:      uuid.New(),
		MachineSignPub: machineSignPub,
		MachineEncPub:  randomBytes(t, 32),
		ExpiresAt:      time.Now().Add(5 * time.Minute),
		RelayChallenge: randomBytes(t, 32),
	}

	masterSignPub, masterSignPriv, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)
	inputMasterEncPub := randomBytes(t, 32)
	keyringTargetMasterEncPub := flippedBytes(inputMasterEncPub)
	masterFingerprint := crypto.HashKeyFingerprint(masterSignPub)

	keyringPayload := crypto.KeyringUpdatePayload{
		MasterID:                       masterID.String(),
		Seq:                            1,
		PrevHash:                       "",
		Action:                         string(KeyringActionAdd),
		TargetMasterSignPub:            base64.StdEncoding.EncodeToString(masterSignPub),
		TargetMasterEncPub:             base64.StdEncoding.EncodeToString(keyringTargetMasterEncPub),
		SignerMasterSignKeyFingerprint: masterFingerprint,
	}

	authRepo := &authRequestRepoMock{
		findByIDForTxFn: func(ctx context.Context, id uuid.UUID) (domain.AuthRequest, error) {
			require.Equal(t, requestID, id)
			return authReq, nil
		},
	}
	masterKeyRepo := &masterKeyRepoMock{
		findByFingerprintFn: func(ctx context.Context, fingerprint string) (domain.MasterKey, error) {
			require.Equal(t, masterFingerprint, fingerprint)
			return domain.MasterKey{}, repository.ErrMasterKeyNotFound
		},
	}
	masterIdentityRepo := &masterIdentityRepoMock{
		findByIDFn: func(ctx context.Context, id uuid.UUID) (domain.MasterIdentity, error) {
			require.Equal(t, masterID, id)
			return domain.MasterIdentity{}, repository.ErrMasterIdentityNotFound
		},
	}

	svc := &AuthServiceImpl{
		machines:       noopMachineRepo{},
		keyringUpdates: noopKeyringUpdateRepo{},
		txRunner: txRunnerMock{repos: repository.TxRepositories{
			AuthRequests:     authRepo,
			MasterIdentities: masterIdentityRepo,
			MasterKeys:       masterKeyRepo,
			Machines:         noopMachineRepo{},
			KeyringUpdates:   noopKeyringUpdateRepo{},
		}},
		relaySignPriv: relayPriv,
		relaySignPub:  relayPub,
	}

	status, err := svc.ApproveAuthRequest(context.Background(), requestID, AuthApproveInput{
		MasterID:          masterID.String(),
		MasterSignPub:     masterSignPub,
		MasterEncPub:      inputMasterEncPub,
		ApprovalSignature: signApproval(t, authReq, masterSignPriv),
		KeyringUpdate: &KeyringUpdateInput{
			MasterID:                       masterID.String(),
			Seq:                            1,
			PrevHash:                       "",
			Action:                         KeyringActionAdd,
			TargetMasterSignPub:            masterSignPub,
			TargetMasterEncPub:             keyringTargetMasterEncPub,
			SignerMasterSignKeyFingerprint: masterFingerprint,
			Signature:                      ed25519.Sign(masterSignPriv, []byte(crypto.BuildKeyringUpdateMessage(keyringPayload))),
		},
	})
	require.ErrorIs(t, err, ErrKeyringUpdateTargetMasterEncMismatch)
	assert.Nil(t, status)
}

func TestAuthService_ApproveAuthRequest_LogsApprovalSuccess(t *testing.T) {
	buf := testutil.CaptureSlog(t)

	relayPub, relayPriv, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)

	requestID := uuid.New()
	machineID := uuid.New()
	masterID := uuid.New()

	machineSignPub, _, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)
	authReq := domain.AuthRequest{
		ID:             requestID,
		MachineID:      machineID,
		MachineSignPub: machineSignPub,
		MachineEncPub:  randomBytes(t, 32),
		ExpiresAt:      time.Now().Add(5 * time.Minute),
		RelayChallenge: randomBytes(t, 32),
	}

	masterSignPub, masterSignPriv, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)
	masterEncPub := randomBytes(t, 32)
	masterFingerprint := crypto.HashKeyFingerprint(masterSignPub)

	updatedAuthReq := authReq
	authRepo := &authRequestRepoMock{
		findByIDFn: func(ctx context.Context, id uuid.UUID) (domain.AuthRequest, error) {
			require.Equal(t, requestID, id)
			return updatedAuthReq, nil
		},
		findByIDForTxFn: func(ctx context.Context, id uuid.UUID) (domain.AuthRequest, error) {
			require.Equal(t, requestID, id)
			return updatedAuthReq, nil
		},
		updateFn: func(ctx context.Context, req *domain.AuthRequest) error {
			updatedAuthReq = *req
			return nil
		},
	}
	masterKeyRepo := &masterKeyRepoMock{
		findByFingerprintFn: func(ctx context.Context, fingerprint string) (domain.MasterKey, error) {
			require.Equal(t, masterFingerprint, fingerprint)
			return domain.MasterKey{
				MasterID:                 masterID,
				MasterSignKeyFingerprint: masterFingerprint,
				MasterSignPub:            masterSignPub,
				MasterEncPub:             masterEncPub,
			}, nil
		},
		listByMasterIDFn: func(ctx context.Context, id uuid.UUID) ([]domain.MasterKey, error) {
			require.Equal(t, masterID, id)
			return []domain.MasterKey{{
				MasterID:                 masterID,
				MasterSignKeyFingerprint: masterFingerprint,
				MasterSignPub:            masterSignPub,
				MasterEncPub:             masterEncPub,
			}}, nil
		},
	}
	masterIdentityRepo := &masterIdentityRepoMock{
		findByIDFn: func(ctx context.Context, id uuid.UUID) (domain.MasterIdentity, error) {
			require.Equal(t, masterID, id)
			return domain.MasterIdentity{
				ID:              masterID,
				KeyringSeq:      1,
				KeyringHeadHash: "head",
			}, nil
		},
	}

	svc := &AuthServiceImpl{
		authRequests:     authRepo,
		masterKeys:       masterKeyRepo,
		masterIdentities: masterIdentityRepo,
		machines:         noopMachineRepo{},
		keyringUpdates:   noopKeyringUpdateRepo{},
		txRunner: txRunnerMock{repos: repository.TxRepositories{
			AuthRequests:     authRepo,
			MasterIdentities: masterIdentityRepo,
			MasterKeys:       masterKeyRepo,
			Machines:         noopMachineRepo{},
			KeyringUpdates:   noopKeyringUpdateRepo{},
		}},
		relaySignPriv: relayPriv,
		relaySignPub:  relayPub,
	}

	ctx := logging.WithClientIP(context.Background(), "198.51.100.22")
	status, err := svc.ApproveAuthRequest(ctx, requestID, AuthApproveInput{
		MasterSignPub:     masterSignPub,
		MasterEncPub:      masterEncPub,
		ApprovalSignature: signApproval(t, authReq, masterSignPriv),
	})
	require.NoError(t, err)
	require.NotNil(t, status)
	assert.Equal(t, AuthStatusApproved, status.State)
	assert.Equal(t, masterID.String(), status.MasterID)

	entry := testutil.FindEntryByEvent(testutil.ParseLogEntries(t, buf), logging.EventAuthRequestApproved)
	require.NotNil(t, entry)
	assert.Equal(t, logging.ResultSuccess, entry["result"])
	assert.Equal(t, requestID.String(), entry["auth_request_id"])
	assert.Equal(t, machineID.String(), entry["machine_id"])
	assert.Equal(t, masterID.String(), entry["master_id"])
	assert.Equal(t, masterFingerprint, entry["master_sign_key_fingerprint"])
	assert.Equal(t, "198.51.100.22", entry["client_ip"])
	assert.NotContains(t, buf.String(), base64.StdEncoding.EncodeToString(masterEncPub))
	assert.NotContains(t, buf.String(), base64.StdEncoding.EncodeToString(authReq.RelayChallenge))
}

func signApproval(t *testing.T, authReq domain.AuthRequest, signerPriv ed25519.PrivateKey) []byte {
	t.Helper()

	msg := crypto.BuildApprovalMessage(
		authReq.ID.String(),
		base64.StdEncoding.EncodeToString(authReq.MachineSignPub),
		base64.StdEncoding.EncodeToString(authReq.MachineEncPub),
		base64.StdEncoding.EncodeToString(authReq.RelayChallenge),
		authReq.ExpiresAt.Unix(),
	)
	return ed25519.Sign(signerPriv, []byte(msg))
}

func randomBytes(t *testing.T, n int) []byte {
	t.Helper()

	buf := make([]byte, n)
	_, err := rand.Read(buf)
	require.NoError(t, err)
	return buf
}

func flippedBytes(in []byte) []byte {
	out := append([]byte(nil), in...)
	if len(out) == 0 {
		return out
	}
	out[0] ^= 0xff
	return out
}

func ptrTime(t time.Time) *time.Time {
	return &t
}

func ptrString(s string) *string {
	return &s
}
