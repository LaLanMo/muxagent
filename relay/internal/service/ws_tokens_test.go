package service

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"strconv"
	"testing"
	"time"

	"github.com/LaLanMo/muxagent/relay/internal/domain"
	"github.com/LaLanMo/muxagent/relay/internal/infra/crypto"
	"github.com/LaLanMo/muxagent/relay/internal/repository"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type masterKeyRepoStub struct {
	findByMasterFingerprintFn func(ctx context.Context, masterID uuid.UUID, fingerprint string) (domain.MasterKey, error)
}

func (m *masterKeyRepoStub) Create(ctx context.Context, key *domain.MasterKey) error {
	return nil
}

func (m *masterKeyRepoStub) FindByFingerprint(ctx context.Context, fingerprint string) (domain.MasterKey, error) {
	return domain.MasterKey{}, repository.ErrMasterKeyNotFound
}

func (m *masterKeyRepoStub) FindByMasterAndFingerprint(ctx context.Context, masterID uuid.UUID, fingerprint string) (domain.MasterKey, error) {
	if m.findByMasterFingerprintFn != nil {
		return m.findByMasterFingerprintFn(ctx, masterID, fingerprint)
	}
	return domain.MasterKey{}, repository.ErrMasterKeyNotFound
}

func (m *masterKeyRepoStub) ListByMasterID(ctx context.Context, masterID uuid.UUID) ([]domain.MasterKey, error) {
	return nil, nil
}

func (m *masterKeyRepoStub) Revoke(ctx context.Context, masterID uuid.UUID, fingerprint string, revokedAt time.Time) error {
	return nil
}

func TestTokenService_VerifyConnectToken(t *testing.T) {
	masterID := uuid.New()
	signPub, signPriv, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)
	fingerprint := crypto.HashKeyFingerprint(signPub)

	expiresAt := time.Now().Add(2 * time.Hour).UTC().Unix()

	sign := func(msg string, priv ed25519.PrivateKey) string {
		sig := ed25519.Sign(priv, []byte(msg))
		return base64.RawURLEncoding.EncodeToString([]byte(msg)) + "." + base64.RawURLEncoding.EncodeToString(sig)
	}

	validPayload := TokenPrefixConnect + "|" + masterID.String() + "|" + fingerprint + "|" + strconv.FormatInt(expiresAt, 10)
	validToken := sign(validPayload, signPriv)

	tests := []struct {
		name      string
		token     string
		repoKey   domain.MasterKey
		repoErr   error
		wantErr   error
		wantClaim bool
	}{
		{
			name:      "valid",
			token:     validToken,
			repoKey:   domain.MasterKey{MasterSignPub: signPub},
			wantClaim: true,
		},
		{
			name:    "invalid prefix",
			token:   sign("bad-prefix|"+masterID.String()+"|"+fingerprint+"|"+strconv.FormatInt(expiresAt, 10), signPriv),
			wantErr: ErrInvalidTokenFormat,
		},
		{
			name:    "expired",
			token:   sign(TokenPrefixConnect+"|"+masterID.String()+"|"+fingerprint+"|"+strconv.FormatInt(time.Now().Add(-time.Hour).Unix(), 10), signPriv),
			wantErr: ErrTokenExpired,
		},
		{
			name:    "invalid signature",
			token:   sign(validPayload, ed25519.NewKeyFromSeed(make([]byte, ed25519.SeedSize))),
			wantErr: ErrInvalidConnectToken,
		},
		{
			name:    "revoked key",
			token:   validToken,
			repoKey: domain.MasterKey{MasterSignPub: signPub, RevokedAt: ptrTime(time.Now())},
			wantErr: ErrMasterKeyRevoked,
		},
		{
			name:    "master key not found",
			token:   validToken,
			repoErr: repository.ErrMasterKeyNotFound,
			wantErr: ErrInvalidConnectToken,
		},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			repo := &masterKeyRepoStub{
				findByMasterFingerprintFn: func(ctx context.Context, id uuid.UUID, fp string) (domain.MasterKey, error) {
					if tt.repoErr != nil {
						return domain.MasterKey{}, tt.repoErr
					}
					return tt.repoKey, nil
				},
			}
			svc := NewTokenService(repo, &machineRepoMock{})
			claims, err := svc.VerifyConnectToken(context.Background(), tt.token)
			if tt.wantErr != nil {
				require.Error(t, err)
				assert.ErrorIs(t, err, tt.wantErr)
				return
			}
			require.NoError(t, err)
			if tt.wantClaim {
				assert.Equal(t, masterID, claims.MasterID)
				assert.Equal(t, fingerprint, claims.MasterSignKeyFingerprint)
			}
		})
	}
}

func TestTokenService_VerifyMachineAccessToken(t *testing.T) {
	masterID := uuid.New()
	machineID := uuid.New()
	machineSignPub, machineSignPriv, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)
	fingerprint := crypto.HashKeyFingerprint(machineSignPub)
	expiresAt := time.Now().Add(time.Hour).UTC().Unix()

	sign := func(msg string, priv ed25519.PrivateKey) string {
		sig := ed25519.Sign(priv, []byte(msg))
		return base64.RawURLEncoding.EncodeToString([]byte(msg)) + "." + base64.RawURLEncoding.EncodeToString(sig)
	}

	validPayload := TokenPrefixMachineAccess + "|" + masterID.String() + "|" + machineID.String() + "|" + fingerprint + "|" + strconv.FormatInt(expiresAt, 10)
	validToken := sign(validPayload, machineSignPriv)

	validMachine := domain.Machine{
		ID:                        machineID,
		MasterID:                  masterID,
		MachineSignKeyFingerprint: fingerprint,
		MachineSignPub:            machineSignPub,
	}

	tests := []struct {
		name       string
		token      string
		machine    domain.Machine
		machineErr error
		wantErr    error
	}{
		{
			name:    "valid",
			token:   validToken,
			machine: validMachine,
		},
		{
			name:    "invalid prefix",
			token:   sign("bad-prefix|"+masterID.String()+"|"+machineID.String()+"|"+fingerprint+"|"+strconv.FormatInt(expiresAt, 10), machineSignPriv),
			wantErr: ErrInvalidTokenFormat,
		},
		{
			name:    "expired",
			token:   sign(TokenPrefixMachineAccess+"|"+masterID.String()+"|"+machineID.String()+"|"+fingerprint+"|"+strconv.FormatInt(time.Now().Add(-time.Hour).Unix(), 10), machineSignPriv),
			wantErr: ErrTokenExpired,
		},
		{
			name:       "machine not found",
			token:      validToken,
			machineErr: repository.ErrMachineNotFound,
			wantErr:    ErrInvalidMachineAccessToken,
		},
		{
			name:  "master ID mismatch",
			token: validToken,
			machine: domain.Machine{
				ID:                        machineID,
				MasterID:                  uuid.New(),
				MachineSignKeyFingerprint: fingerprint,
				MachineSignPub:            machineSignPub,
			},
			wantErr: ErrInvalidMachineAccessToken,
		},
		{
			name:  "fingerprint mismatch",
			token: validToken,
			machine: domain.Machine{
				ID:                        machineID,
				MasterID:                  masterID,
				MachineSignKeyFingerprint: "wrong-fingerprint",
				MachineSignPub:            machineSignPub,
			},
			wantErr: ErrInvalidMachineAccessToken,
		},
		{
			name:  "machine revoked",
			token: validToken,
			machine: domain.Machine{
				ID:                        machineID,
				MasterID:                  masterID,
				MachineSignKeyFingerprint: fingerprint,
				MachineSignPub:            machineSignPub,
				RevokedAt:                 ptrTime(time.Now()),
			},
			wantErr: ErrMachineRevoked,
		},
		{
			name:    "invalid signature",
			token:   sign(validPayload, ed25519.NewKeyFromSeed(make([]byte, ed25519.SeedSize))),
			machine: validMachine,
			wantErr: ErrInvalidMachineAccessToken,
		},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			machineRepo := &machineRepoMock{
				findFn: func(ctx context.Context, id uuid.UUID) (domain.Machine, error) {
					if tt.machineErr != nil {
						return domain.Machine{}, tt.machineErr
					}
					return tt.machine, nil
				},
			}
			svc := NewTokenService(&masterKeyRepoStub{}, machineRepo)
			claims, err := svc.VerifyMachineAccessToken(context.Background(), tt.token)
			if tt.wantErr != nil {
				require.Error(t, err)
				assert.ErrorIs(t, err, tt.wantErr)
				return
			}
			require.NoError(t, err)
			assert.Equal(t, masterID, claims.MasterID)
			assert.Equal(t, machineID, claims.MachineID)
			assert.Equal(t, fingerprint, claims.Fingerprint)
		})
	}
}

func TestTokenService_VerifyMachineToken(t *testing.T) {
	masterID := uuid.New()
	machineID := uuid.New()
	signPub, signPriv, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)
	fingerprint := crypto.HashKeyFingerprint(signPub)
	expiresAt := time.Now().Add(time.Hour).UTC().Unix()

	sign := func(msg string, priv ed25519.PrivateKey) string {
		sig := ed25519.Sign(priv, []byte(msg))
		return base64.RawURLEncoding.EncodeToString([]byte(msg)) + "." + base64.RawURLEncoding.EncodeToString(sig)
	}
	validPayload := TokenPrefixMachine + "|" + masterID.String() + "|" + machineID.String() + "|" + fingerprint + "|" + strconv.FormatInt(expiresAt, 10)
	validToken := sign(validPayload, signPriv)

	tests := []struct {
		name    string
		token   string
		repoKey domain.MasterKey
		repoErr error
		wantErr error
	}{
		{
			name:    "valid",
			token:   validToken,
			repoKey: domain.MasterKey{MasterSignPub: signPub},
		},
		{
			name:    "invalid prefix",
			token:   sign("bad-prefix|"+masterID.String()+"|"+machineID.String()+"|"+fingerprint+"|"+strconv.FormatInt(expiresAt, 10), signPriv),
			wantErr: ErrInvalidTokenFormat,
		},
		{
			name:    "expired",
			token:   sign(TokenPrefixMachine+"|"+masterID.String()+"|"+machineID.String()+"|"+fingerprint+"|"+strconv.FormatInt(time.Now().Add(-time.Hour).Unix(), 10), signPriv),
			wantErr: ErrTokenExpired,
		},
		{
			name:    "invalid signature",
			token:   sign(validPayload, ed25519.NewKeyFromSeed(make([]byte, ed25519.SeedSize))),
			wantErr: ErrInvalidMachineToken,
		},
		{
			name:    "revoked key",
			token:   validToken,
			repoKey: domain.MasterKey{MasterSignPub: signPub, RevokedAt: ptrTime(time.Now())},
			wantErr: ErrMasterKeyRevoked,
		},
		{
			name:    "master key not found",
			token:   validToken,
			repoErr: repository.ErrMasterKeyNotFound,
			wantErr: ErrInvalidMachineToken,
		},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			repo := &masterKeyRepoStub{
				findByMasterFingerprintFn: func(ctx context.Context, id uuid.UUID, fp string) (domain.MasterKey, error) {
					if tt.repoErr != nil {
						return domain.MasterKey{}, tt.repoErr
					}
					return tt.repoKey, nil
				},
			}
			svc := NewTokenService(repo, &machineRepoMock{})
			claims, err := svc.VerifyMachineToken(context.Background(), tt.token)
			if tt.wantErr != nil {
				require.Error(t, err)
				assert.ErrorIs(t, err, tt.wantErr)
				return
			}
			require.NoError(t, err)
			assert.Equal(t, masterID, claims.MasterID)
			assert.Equal(t, machineID, claims.MachineID)
		})
	}
}
