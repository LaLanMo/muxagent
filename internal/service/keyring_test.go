package service

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"testing"
	"time"

	"github.com/LaLanMo/muxagent-relay/internal/domain"
	"github.com/LaLanMo/muxagent-relay/internal/infra/crypto"
	"github.com/LaLanMo/muxagent-relay/internal/repository"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type keyringMasterIdentityRepoMock struct {
	findByIDFn      func(ctx context.Context, id uuid.UUID) (domain.MasterIdentity, error)
	updateKeyringFn func(ctx context.Context, id uuid.UUID, seq int, headHash string) error
}

func (m *keyringMasterIdentityRepoMock) Create(ctx context.Context, identity *domain.MasterIdentity) error {
	return nil
}

func (m *keyringMasterIdentityRepoMock) FindByID(ctx context.Context, id uuid.UUID) (domain.MasterIdentity, error) {
	if m.findByIDFn != nil {
		return m.findByIDFn(ctx, id)
	}
	return domain.MasterIdentity{}, repository.ErrMasterIdentityNotFound
}

func (m *keyringMasterIdentityRepoMock) UpdateKeyringState(ctx context.Context, id uuid.UUID, seq int, headHash string) error {
	if m.updateKeyringFn != nil {
		return m.updateKeyringFn(ctx, id, seq, headHash)
	}
	return nil
}

type keyringMasterKeyRepoMock struct {
	findByMasterFingerprintFn func(ctx context.Context, masterID uuid.UUID, fingerprint string) (domain.MasterKey, error)
	findByFingerprintFn       func(ctx context.Context, fingerprint string) (domain.MasterKey, error)
	createFn                  func(ctx context.Context, key *domain.MasterKey) error
	revokeFn                  func(ctx context.Context, masterID uuid.UUID, fingerprint string, revokedAt time.Time) error
}

func (m *keyringMasterKeyRepoMock) Create(ctx context.Context, key *domain.MasterKey) error {
	if m.createFn != nil {
		return m.createFn(ctx, key)
	}
	return nil
}

func (m *keyringMasterKeyRepoMock) FindByFingerprint(ctx context.Context, fingerprint string) (domain.MasterKey, error) {
	if m.findByFingerprintFn != nil {
		return m.findByFingerprintFn(ctx, fingerprint)
	}
	return domain.MasterKey{}, repository.ErrMasterKeyNotFound
}

func (m *keyringMasterKeyRepoMock) FindByMasterAndFingerprint(ctx context.Context, masterID uuid.UUID, fingerprint string) (domain.MasterKey, error) {
	if m.findByMasterFingerprintFn != nil {
		return m.findByMasterFingerprintFn(ctx, masterID, fingerprint)
	}
	return domain.MasterKey{}, repository.ErrMasterKeyNotFound
}

func (m *keyringMasterKeyRepoMock) ListByMasterID(ctx context.Context, masterID uuid.UUID) ([]domain.MasterKey, error) {
	return nil, nil
}

func (m *keyringMasterKeyRepoMock) Revoke(ctx context.Context, masterID uuid.UUID, fingerprint string, revokedAt time.Time) error {
	if m.revokeFn != nil {
		return m.revokeFn(ctx, masterID, fingerprint, revokedAt)
	}
	return nil
}

type keyringUpdateRepoMock struct {
	createFn func(ctx context.Context, update *domain.KeyringUpdate) error
	listFn   func(ctx context.Context, masterID uuid.UUID, fromSeq int, limit int) ([]domain.KeyringUpdate, error)
}

func (m *keyringUpdateRepoMock) Create(ctx context.Context, update *domain.KeyringUpdate) error {
	if m.createFn != nil {
		return m.createFn(ctx, update)
	}
	return nil
}

func (m *keyringUpdateRepoMock) ListByMasterIDFromSeq(ctx context.Context, masterID uuid.UUID, fromSeq int, limit int) ([]domain.KeyringUpdate, error) {
	if m.listFn != nil {
		return m.listFn(ctx, masterID, fromSeq, limit)
	}
	return nil, nil
}

type txRunnerMock struct {
	repos repository.TxRepositories
}

func (m txRunnerMock) InTx(ctx context.Context, fn func(repos repository.TxRepositories) error) error {
	return fn(m.repos)
}

func TestKeyringService_UpdateKeyring(t *testing.T) {
	masterID := uuid.New()
	signerPub, signerPriv, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)
	signerFingerprint := crypto.HashKeyFingerprint(signerPub)
	targetPub, _, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)

	tests := []struct {
		name       string
		input      KeyringUpdateInput
		setupRepos func() repository.TxRepositories
		wantErr    error
	}{
		{
			name: "invalid action",
			input: KeyringUpdateInput{
				Action: KeyringAction("noop"),
			},
			setupRepos: func() repository.TxRepositories {
				return repository.TxRepositories{}
			},
			wantErr: ErrInvalidAction,
		},
		{
			name: "identity not found",
			input: KeyringUpdateInput{
				Action: KeyringActionAdd,
			},
			setupRepos: func() repository.TxRepositories {
				return repository.TxRepositories{
					MasterIdentities: &keyringMasterIdentityRepoMock{
						findByIDFn: func(ctx context.Context, id uuid.UUID) (domain.MasterIdentity, error) {
							return domain.MasterIdentity{}, repository.ErrMasterIdentityNotFound
						},
					},
					MasterKeys:     &keyringMasterKeyRepoMock{},
					KeyringUpdates: &keyringUpdateRepoMock{},
				}
			},
			wantErr: ErrMasterIdentityNotFound,
		},
		{
			name: "signer not found",
			input: KeyringUpdateInput{
				MasterID:                       masterID.String(),
				Seq:                            2,
				PrevHash:                       "head",
				Action:                         KeyringActionAdd,
				TargetMasterSignPub:            targetPub,
				TargetMasterEncPub:             []byte("enc"),
				SignerMasterSignKeyFingerprint: signerFingerprint,
				Signature:                      []byte("sig"),
			},
			setupRepos: func() repository.TxRepositories {
				return repository.TxRepositories{
					MasterIdentities: &keyringMasterIdentityRepoMock{
						findByIDFn: func(ctx context.Context, id uuid.UUID) (domain.MasterIdentity, error) {
							return domain.MasterIdentity{ID: masterID, KeyringSeq: 1, KeyringHeadHash: "head"}, nil
						},
					},
					MasterKeys: &keyringMasterKeyRepoMock{
						findByMasterFingerprintFn: func(ctx context.Context, masterID uuid.UUID, fingerprint string) (domain.MasterKey, error) {
							return domain.MasterKey{}, repository.ErrMasterKeyNotFound
						},
					},
					KeyringUpdates: &keyringUpdateRepoMock{},
				}
			},
			wantErr: ErrSignerMasterKeyNotFound,
		},
		{
			name: "success add",
			input: func() KeyringUpdateInput {
				payload := crypto.KeyringUpdatePayload{
					MasterID:                       masterID.String(),
					Seq:                            2,
					PrevHash:                       "head",
					Action:                         string(KeyringActionAdd),
					TargetMasterSignPub:            base64.StdEncoding.EncodeToString(targetPub),
					TargetMasterEncPub:             base64.StdEncoding.EncodeToString([]byte("enc")),
					SignerMasterSignKeyFingerprint: signerFingerprint,
				}
				sig := ed25519.Sign(signerPriv, []byte(crypto.BuildKeyringUpdateMessage(payload)))
				return KeyringUpdateInput{
					MasterID:                       payload.MasterID,
					Seq:                            payload.Seq,
					PrevHash:                       payload.PrevHash,
					Action:                         KeyringActionAdd,
					TargetMasterSignPub:            targetPub,
					TargetMasterEncPub:             []byte("enc"),
					SignerMasterSignKeyFingerprint: signerFingerprint,
					Signature:                      sig,
				}
			}(),
			setupRepos: func() repository.TxRepositories {
				return repository.TxRepositories{
					MasterIdentities: &keyringMasterIdentityRepoMock{
						findByIDFn: func(ctx context.Context, id uuid.UUID) (domain.MasterIdentity, error) {
							return domain.MasterIdentity{ID: masterID, KeyringSeq: 1, KeyringHeadHash: "head"}, nil
						},
					},
					MasterKeys: &keyringMasterKeyRepoMock{
						findByMasterFingerprintFn: func(ctx context.Context, masterID uuid.UUID, fingerprint string) (domain.MasterKey, error) {
							return domain.MasterKey{MasterSignPub: signerPub}, nil
						},
						findByFingerprintFn: func(ctx context.Context, fingerprint string) (domain.MasterKey, error) {
							return domain.MasterKey{}, repository.ErrMasterKeyNotFound
						},
					},
					KeyringUpdates: &keyringUpdateRepoMock{},
				}
			},
		},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			repos := tt.setupRepos()
			svc := NewKeyringService(repos.MasterIdentities, repos.MasterKeys, repos.KeyringUpdates, txRunnerMock{repos: repos})
			err := svc.UpdateKeyring(context.Background(), masterID, tt.input)
			if tt.wantErr != nil {
				require.Error(t, err)
				assert.ErrorIs(t, err, tt.wantErr)
				return
			}
			require.NoError(t, err)
		})
	}
}
