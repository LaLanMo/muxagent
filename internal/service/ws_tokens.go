package service

import (
	"context"
	"encoding/base64"
	"errors"
	"strconv"
	"strings"
	"time"

	"github.com/LaLanMo/muxagent-relay/internal/infra/crypto"
	"github.com/LaLanMo/muxagent-relay/internal/repository"
	"github.com/google/uuid"
)

const (
	TokenPrefixConnect = "muxagent-connect-token-v1"
	TokenPrefixMachine = "muxagent-machine-token-v1"
)

type ConnectTokenClaims struct {
	MasterID                 uuid.UUID
	MasterSignKeyFingerprint string
	ExpiresAt                time.Time
}

type MachineTokenClaims struct {
	MasterID                 uuid.UUID
	MachineID                uuid.UUID
	MasterSignKeyFingerprint string
	ExpiresAt                time.Time
}

type TokenService interface {
	VerifyConnectToken(ctx context.Context, token string) (ConnectTokenClaims, error)
	VerifyMachineToken(ctx context.Context, token string) (MachineTokenClaims, error)
}

type tokenServiceImpl struct {
	masterKeys repository.MasterKeyRepository
}

func NewTokenService(masterKeys repository.MasterKeyRepository) TokenService {
	return &tokenServiceImpl{masterKeys: masterKeys}
}

func (s *tokenServiceImpl) VerifyConnectToken(ctx context.Context, token string) (ConnectTokenClaims, error) {
	payload, sig, err := decodeToken(token)
	if err != nil {
		return ConnectTokenClaims{}, err
	}
	parts := strings.Split(payload, "|")
	if len(parts) != 4 || parts[0] != TokenPrefixConnect {
		return ConnectTokenClaims{}, ErrInvalidTokenFormat
	}
	masterID, err := uuid.Parse(parts[1])
	if err != nil {
		return ConnectTokenClaims{}, ErrInvalidConnectToken
	}
	fingerprint := parts[2]
	expiresAt, err := parseUnix(parts[3])
	if err != nil {
		return ConnectTokenClaims{}, ErrInvalidConnectToken
	}
	if time.Now().After(expiresAt) {
		return ConnectTokenClaims{}, ErrTokenExpired
	}
	if err := s.verifySignature(ctx, masterID, fingerprint, payload, sig, ErrInvalidConnectToken); err != nil {
		return ConnectTokenClaims{}, err
	}
	return ConnectTokenClaims{
		MasterID:                 masterID,
		MasterSignKeyFingerprint: fingerprint,
		ExpiresAt:                expiresAt,
	}, nil
}

func (s *tokenServiceImpl) VerifyMachineToken(ctx context.Context, token string) (MachineTokenClaims, error) {
	payload, sig, err := decodeToken(token)
	if err != nil {
		return MachineTokenClaims{}, err
	}
	parts := strings.Split(payload, "|")
	if len(parts) != 5 || parts[0] != TokenPrefixMachine {
		return MachineTokenClaims{}, ErrInvalidTokenFormat
	}
	masterID, err := uuid.Parse(parts[1])
	if err != nil {
		return MachineTokenClaims{}, ErrInvalidMachineToken
	}
	machineID, err := uuid.Parse(parts[2])
	if err != nil {
		return MachineTokenClaims{}, ErrInvalidMachineToken
	}
	fingerprint := parts[3]
	expiresAt, err := parseUnix(parts[4])
	if err != nil {
		return MachineTokenClaims{}, ErrInvalidMachineToken
	}
	if time.Now().After(expiresAt) {
		return MachineTokenClaims{}, ErrTokenExpired
	}
	if err := s.verifySignature(ctx, masterID, fingerprint, payload, sig, ErrInvalidMachineToken); err != nil {
		return MachineTokenClaims{}, err
	}
	return MachineTokenClaims{
		MasterID:                 masterID,
		MachineID:                machineID,
		MasterSignKeyFingerprint: fingerprint,
		ExpiresAt:                expiresAt,
	}, nil
}

func decodeToken(token string) (payload string, signature []byte, err error) {
	parts := strings.Split(token, ".")
	if len(parts) != 2 {
		return "", nil, ErrInvalidTokenFormat
	}
	payloadBytes, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return "", nil, ErrInvalidTokenFormat
	}
	sigBytes, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return "", nil, ErrInvalidTokenFormat
	}
	return string(payloadBytes), sigBytes, nil
}

func parseUnix(value string) (time.Time, error) {
	raw, err := strconv.ParseInt(value, 10, 64)
	if err != nil {
		return time.Time{}, err
	}
	return time.Unix(raw, 0).UTC(), nil
}

func (s *tokenServiceImpl) verifySignature(ctx context.Context, masterID uuid.UUID, fingerprint string, payload string, sig []byte, invalidErr error) error {
	masterKey, err := s.masterKeys.FindByMasterAndFingerprint(ctx, masterID, fingerprint)
	if err != nil {
		if errors.Is(err, repository.ErrMasterKeyNotFound) {
			return invalidErr
		}
		return err
	}
	if masterKey.RevokedAt != nil {
		return ErrMasterKeyRevoked
	}
	if !crypto.VerifySignature(masterKey.MasterSignPub, []byte(payload), sig) {
		return invalidErr
	}
	return nil
}
