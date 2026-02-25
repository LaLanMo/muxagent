package service

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"strconv"
	"time"

	"github.com/LaLanMo/muxagent-relay/internal/domain"
	"github.com/LaLanMo/muxagent-relay/internal/infra/crypto"
	"github.com/LaLanMo/muxagent-relay/internal/repository"
	"github.com/google/uuid"
)

const (
	// AuthRequestTTL is how long an auth request remains valid.
	AuthRequestTTL = 5 * time.Minute
	// CleanupInterval is how often expired requests are cleaned up.
	CleanupInterval = 1 * time.Minute
)

type AuthService interface {
	CreateAuthRequest(ctx context.Context, machineID uuid.UUID, machineSignPub, machineEncPub []byte, hostname string) (*domain.AuthRequest, error)
	GetAuthStatus(ctx context.Context, requestID uuid.UUID) (*AuthStatus, error)
	ApproveAuthRequest(ctx context.Context, requestID uuid.UUID, input AuthApproveInput) (*AuthStatus, error)
	StartCleanup() func()
}

type AuthServiceImpl struct {
	authRequests     repository.AuthRequestRepository
	masterIdentities repository.MasterIdentityRepository
	masterKeys       repository.MasterKeyRepository
	machines         repository.MachineRepository
	keyringUpdates   repository.KeyringUpdateRepository
	txRunner         repository.TxRunner
	relaySignPriv    ed25519.PrivateKey
	relaySignPub     ed25519.PublicKey
}

func NewAuthService(
	authRequests repository.AuthRequestRepository,
	masterIdentities repository.MasterIdentityRepository,
	masterKeys repository.MasterKeyRepository,
	machines repository.MachineRepository,
	keyringUpdates repository.KeyringUpdateRepository,
	txRunner repository.TxRunner,
	relaySignPriv ed25519.PrivateKey,
	relaySignPub ed25519.PublicKey,
) AuthService {
	return &AuthServiceImpl{
		authRequests:     authRequests,
		masterIdentities: masterIdentities,
		masterKeys:       masterKeys,
		machines:         machines,
		keyringUpdates:   keyringUpdates,
		txRunner:         txRunner,
		relaySignPriv:    relaySignPriv,
		relaySignPub:     relaySignPub,
	}
}

// StartCleanup launches a cleanup loop for expired auth requests.
// Returns a stop function.
func (s *AuthServiceImpl) StartCleanup() func() {
	stop := make(chan struct{})
	ticker := time.NewTicker(CleanupInterval)
	go func() {
		defer ticker.Stop()
		for {
			select {
			case <-stop:
				return
			case <-ticker.C:
				cutoff := time.Now().Add(-time.Minute)
				_ = s.authRequests.DeleteExpired(context.Background(), cutoff)
			}
		}
	}()
	return func() { close(stop) }
}

func (s *AuthServiceImpl) CreateAuthRequest(ctx context.Context, machineID uuid.UUID, machineSignPub, machineEncPub []byte, hostname string) (*domain.AuthRequest, error) {
	challenge := make([]byte, 32)
	if _, err := rand.Read(challenge); err != nil {
		return nil, err
	}
	now := time.Now()
	req := &domain.AuthRequest{
		ID:             uuid.New(),
		MachineID:      machineID,
		MachineSignPub: machineSignPub,
		MachineEncPub:  machineEncPub,
		Hostname:       hostname,
		ExpiresAt:      now.Add(AuthRequestTTL),
		RelayChallenge: challenge,
	}
	if err := s.authRequests.Create(ctx, req); err != nil {
		return nil, err
	}
	return req, nil
}

func (s *AuthServiceImpl) GetAuthStatus(ctx context.Context, requestID uuid.UUID) (*AuthStatus, error) {
	return s.getAuthStatus(ctx, s.authRequests, s.masterKeys, s.masterIdentities, requestID)
}

func (s *AuthServiceImpl) getAuthStatus(
	ctx context.Context,
	authRequests repository.AuthRequestRepository,
	masterKeys repository.MasterKeyRepository,
	masterIdentities repository.MasterIdentityRepository,
	requestID uuid.UUID,
) (*AuthStatus, error) {
	authReq, err := authRequests.FindByID(ctx, requestID)
	if err != nil {
		if errors.Is(err, repository.ErrAuthRequestNotFound) {
			return nil, ErrAuthRequestNotFound
		}
		return nil, err
	}

	now := time.Now()
	state := AuthStatusPending
	if authReq.ApprovedAt != nil {
		state = AuthStatusApproved
	} else if now.After(authReq.ExpiresAt) {
		state = AuthStatusExpired
	}

	status := &AuthStatus{
		State:           state,
		RequestID:       authReq.ID.String(),
		MachineID:       authReq.MachineID.String(),
		MachineSignPub:  base64.StdEncoding.EncodeToString(authReq.MachineSignPub),
		MachineEncPub:   base64.StdEncoding.EncodeToString(authReq.MachineEncPub),
		MachineHostname: authReq.Hostname,
		RelayChallenge:  base64.StdEncoding.EncodeToString(authReq.RelayChallenge),
		ExpiresAt:       authReq.ExpiresAt,
	}

	if authReq.ApprovedAt != nil && authReq.ApprovedByMasterSignKeyFingerprint != nil {
		status.ApprovedAt = authReq.ApprovedAt
		status.ApprovedByMasterSignKeyFingerprint = *authReq.ApprovedByMasterSignKeyFingerprint
		status.ApprovalSignature = base64.StdEncoding.EncodeToString(authReq.ApprovalSignature)

		if masterKey, err := masterKeys.FindByFingerprint(ctx, *authReq.ApprovedByMasterSignKeyFingerprint); err == nil {
			status.MasterID = masterKey.MasterID.String()
			keyring, err := s.loadKeyringState(ctx, masterIdentities, masterKeys, masterKey.MasterID)
			if err != nil {
				return nil, err
			}
			status.Keyring = keyring
		} else if !errors.Is(err, repository.ErrMasterKeyNotFound) {
			return nil, err
		}

		status.RelayPubKey = base64.StdEncoding.EncodeToString(s.relaySignPub)
		payload := buildAuthStatusSignaturePayload(status, authReq.ID.String())
		status.RelaySignature = crypto.SignMessageBase64(s.relaySignPriv, payload)
	}

	return status, nil
}

func (s *AuthServiceImpl) ApproveAuthRequest(ctx context.Context, requestID uuid.UUID, input AuthApproveInput) (*AuthStatus, error) {
	var output *AuthStatus
	err := s.txRunner.InTx(ctx, func(repos repository.TxRepositories) error {
		authReq, err := repos.AuthRequests.FindByIDForUpdate(ctx, requestID)
		if err != nil {
			if errors.Is(err, repository.ErrAuthRequestNotFound) {
				return ErrAuthRequestNotFound
			}
			return err
		}

		if authReq.ApprovedAt != nil {
			status, err := s.getAuthStatus(ctx, repos.AuthRequests, repos.MasterKeys, repos.MasterIdentities, requestID)
			if err != nil {
				return err
			}
			output = status
			return nil
		}

		if time.Now().After(authReq.ExpiresAt) {
			return ErrAuthRequestExpired
		}

		approvalMsg := crypto.BuildApprovalMessage(
			authReq.ID.String(),
			base64.StdEncoding.EncodeToString(authReq.MachineSignPub),
			base64.StdEncoding.EncodeToString(authReq.MachineEncPub),
			base64.StdEncoding.EncodeToString(authReq.RelayChallenge),
			authReq.ExpiresAt.Unix(),
		)
		if !crypto.VerifySignature(input.MasterSignPub, []byte(approvalMsg), input.ApprovalSignature) {
			return ErrInvalidMasterApprovalSignature
		}

		masterSignKeyFingerprint := crypto.HashKeyFingerprint(input.MasterSignPub)
		masterKey, err := repos.MasterKeys.FindByFingerprint(ctx, masterSignKeyFingerprint)
		masterExists := err == nil
		if err != nil && !errors.Is(err, repository.ErrMasterKeyNotFound) {
			return err
		}

		var masterID uuid.UUID
		if masterExists {
			if masterKey.RevokedAt != nil {
				return ErrMasterKeyRevoked
			}
			if !equalBytes(masterKey.MasterEncPub, input.MasterEncPub) {
				return ErrMasterEncPubMismatch
			}
			masterID = masterKey.MasterID
			if input.MasterID != "" {
				if parsed, err := uuid.Parse(input.MasterID); err == nil && parsed != masterID {
					return ErrMasterIDMismatch
				}
			}
		} else {
			if input.KeyringUpdate == nil {
				return ErrKeyringUpdateRequired
			}
			masterIDStr := input.MasterID
			if masterIDStr == "" {
				if input.KeyringUpdate.MasterID == "" {
					return ErrKeyringUpdateMasterIDMissing
				}
				masterIDStr = input.KeyringUpdate.MasterID
			}
			parsedMasterID, err := uuid.Parse(masterIDStr)
			if err != nil {
				return ErrInvalidMasterID
			}
			masterID = parsedMasterID

			if _, err := repos.MasterIdentities.FindByID(ctx, masterID); err == nil {
				return ErrMasterIdentityExists
			} else if !errors.Is(err, repository.ErrMasterIdentityNotFound) {
				return err
			}

			if err := validateInitialKeyringUpdate(input.KeyringUpdate, masterID, input.MasterSignPub, input.MasterEncPub); err != nil {
				return err
			}

			updateMsg := crypto.BuildKeyringUpdateMessage(crypto.KeyringUpdatePayload{
				MasterID:                       input.KeyringUpdate.MasterID,
				Seq:                            input.KeyringUpdate.Seq,
				PrevHash:                       input.KeyringUpdate.PrevHash,
				Action:                         string(input.KeyringUpdate.Action),
				TargetMasterSignPub:            base64.StdEncoding.EncodeToString(input.KeyringUpdate.TargetMasterSignPub),
				TargetMasterEncPub:             base64.StdEncoding.EncodeToString(input.KeyringUpdate.TargetMasterEncPub),
				SignerMasterSignKeyFingerprint: input.KeyringUpdate.SignerMasterSignKeyFingerprint,
			})
			if !crypto.VerifySignature(input.MasterSignPub, []byte(updateMsg), input.KeyringUpdate.Signature) {
				return ErrInvalidKeyringUpdateSignature
			}

			updateHash := crypto.HashBytes([]byte(updateMsg))
			// Initial keyring state: first accepted update sets seq=1 and head=hash(update1).
			if err := repos.MasterIdentities.Create(ctx, &domain.MasterIdentity{
				ID:              masterID,
				KeyringSeq:      input.KeyringUpdate.Seq,
				KeyringHeadHash: updateHash,
			}); err != nil {
				return err
			}

			masterKey = domain.MasterKey{
				ID:                              uuid.New(),
				MasterID:                        masterID,
				MasterSignKeyFingerprint:        masterSignKeyFingerprint,
				MasterSignPub:                   input.MasterSignPub,
				MasterEncPub:                    input.MasterEncPub,
				AddedByMasterSignKeyFingerprint: &masterSignKeyFingerprint,
				KeyringSeqAdded:                 input.KeyringUpdate.Seq,
			}
			if err := repos.MasterKeys.Create(ctx, &masterKey); err != nil {
				return err
			}

			keyUpdate := &domain.KeyringUpdate{
				ID:                             uuid.New(),
				MasterID:                       masterID,
				Seq:                            input.KeyringUpdate.Seq,
				PrevHash:                       input.KeyringUpdate.PrevHash,
				UpdateHash:                     updateHash,
				Action:                         string(input.KeyringUpdate.Action),
				TargetMasterSignKeyFingerprint: masterSignKeyFingerprint,
				TargetMasterSignPub:            input.MasterSignPub,
				TargetMasterEncPub:             input.MasterEncPub,
				SignerMasterSignKeyFingerprint: input.KeyringUpdate.SignerMasterSignKeyFingerprint,
				Signature:                      input.KeyringUpdate.Signature,
			}
			if err := repos.KeyringUpdates.Create(ctx, keyUpdate); err != nil {
				return err
			}
		}

		machineSignKeyFingerprint := crypto.HashKeyFingerprint(authReq.MachineSignPub)
		existingMachine, err := repos.Machines.FindByID(ctx, authReq.MachineID)
		if err == nil {
			if existingMachine.MasterID != masterID {
				return ErrMachineAlreadyBound
			}
			if existingMachine.RevokedAt != nil {
				return ErrMachineRevoked
			}
		} else if !errors.Is(err, repository.ErrMachineNotFound) {
			return err
		} else {
			machine := &domain.Machine{
				ID:                        authReq.MachineID,
				MasterID:                  masterID,
				MachineSignKeyFingerprint: machineSignKeyFingerprint,
				MachineSignPub:            authReq.MachineSignPub,
				MachineEncPub:             authReq.MachineEncPub,
				LastSeenAt:                time.Now(),
			}
			if err := repos.Machines.Create(ctx, machine); err != nil {
				return err
			}
		}

		now := time.Now()
		authReq.ApprovedAt = &now
		authReq.ApprovedByMasterSignKeyFingerprint = &masterSignKeyFingerprint
		authReq.ApprovalSignature = input.ApprovalSignature
		if err := repos.AuthRequests.Update(ctx, &authReq); err != nil {
			return err
		}

		status, err := s.getAuthStatus(ctx, repos.AuthRequests, repos.MasterKeys, repos.MasterIdentities, requestID)
		if err != nil {
			return err
		}
		output = status
		return nil
	})
	if err != nil {
		return nil, err
	}
	return output, nil
}

func (s *AuthServiceImpl) loadKeyringState(
	ctx context.Context,
	masterIdentities repository.MasterIdentityRepository,
	masterKeys repository.MasterKeyRepository,
	masterID uuid.UUID,
) (*KeyringState, error) {
	identity, err := masterIdentities.FindByID(ctx, masterID)
	if err != nil {
		if errors.Is(err, repository.ErrMasterIdentityNotFound) {
			return nil, ErrMasterIdentityNotFound
		}
		return nil, err
	}
	keys, err := masterKeys.ListByMasterID(ctx, masterID)
	if err != nil {
		return nil, err
	}

	out := &KeyringState{
		MasterID: masterID.String(),
		Seq:      identity.KeyringSeq,
		HeadHash: identity.KeyringHeadHash,
		Keys:     make([]MasterKeyState, 0, len(keys)),
	}
	for _, key := range keys {
		out.Keys = append(out.Keys, MasterKeyState{
			MasterSignKeyFingerprint: key.MasterSignKeyFingerprint,
			MasterSignPub:            base64.StdEncoding.EncodeToString(key.MasterSignPub),
			MasterEncPub:             base64.StdEncoding.EncodeToString(key.MasterEncPub),
			RevokedAt:                key.RevokedAt,
		})
	}
	return out, nil
}

func buildAuthStatusSignaturePayload(status *AuthStatus, requestID string) []byte {
	var keysField string
	var keyringSeq int
	var keyringHead string
	if status.Keyring != nil {
		keys := append([]MasterKeyState{}, status.Keyring.Keys...)
		sortMasterKeys(keys)
		parts := make([]string, 0, len(keys))
		for _, key := range keys {
			revoked := int64(0)
			if key.RevokedAt != nil {
				revoked = key.RevokedAt.Unix()
			}
			parts = append(parts, key.MasterSignKeyFingerprint+","+key.MasterSignPub+","+key.MasterEncPub+","+int64ToString(revoked))
		}
		keysField = joinStrings(parts, ";")
		keyringSeq = status.Keyring.Seq
		keyringHead = status.Keyring.HeadHash
	}
	msg := "muxagent-auth-status-v1|" + requestID + "|" + string(status.State) + "|" +
		status.MachineID + "|" + status.MachineSignPub + "|" + status.MachineEncPub + "|" +
		status.MachineHostname + "|" +
		status.RelayChallenge + "|" + int64ToString(status.ExpiresAt.Unix()) + "|" +
		status.ApprovedByMasterSignKeyFingerprint + "|" + status.ApprovalSignature + "|" +
		status.MasterID + "|" + intToString(keyringSeq) + "|" +
		keyringHead + "|" + keysField
	return []byte(msg)
}

// BuildAuthStatusSignaturePayload is an exported wrapper for tests and verification.
func BuildAuthStatusSignaturePayload(status *AuthStatus, requestID string) []byte {
	return buildAuthStatusSignaturePayload(status, requestID)
}

func validateInitialKeyringUpdate(update *KeyringUpdateInput, masterID uuid.UUID, masterSignPub, masterEncPub []byte) error {
	if update.MasterID == "" {
		return ErrKeyringUpdateMasterIDMissing
	}
	if update.MasterID != masterID.String() {
		return ErrKeyringUpdateMasterIDMismatch
	}
	// The first keyring update must start at seq=1 (no persisted seq=0).
	if update.Seq != 1 {
		return ErrKeyringUpdateSeqInvalid
	}
	if update.PrevHash != "" {
		return ErrKeyringUpdatePrevHashInvalid
	}
	if update.Action != KeyringActionAdd {
		return ErrKeyringUpdateActionInvalid
	}
	if !equalBytes(update.TargetMasterSignPub, masterSignPub) {
		return ErrKeyringUpdateTargetMasterSignMismatch
	}
	if !equalBytes(update.TargetMasterEncPub, masterEncPub) {
		return ErrKeyringUpdateTargetMasterEncMismatch
	}
	computedTarget := crypto.HashKeyFingerprint(masterSignPub)
	if update.SignerMasterSignKeyFingerprint != computedTarget {
		return ErrKeyringUpdateSignerFingerprintMismatch
	}
	return nil
}

func equalBytes(a, b []byte) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func sortMasterKeys(keys []MasterKeyState) {
	for i := 0; i < len(keys); i++ {
		for j := i + 1; j < len(keys); j++ {
			if keys[j].MasterSignKeyFingerprint < keys[i].MasterSignKeyFingerprint {
				keys[i], keys[j] = keys[j], keys[i]
			}
		}
	}
}

func joinStrings(parts []string, sep string) string {
	if len(parts) == 0 {
		return ""
	}
	out := parts[0]
	for i := 1; i < len(parts); i++ {
		out += sep + parts[i]
	}
	return out
}

func int64ToString(v int64) string {
	return strconv.FormatInt(v, 10)
}

func intToString(v int) string {
	return strconv.FormatInt(int64(v), 10)
}
