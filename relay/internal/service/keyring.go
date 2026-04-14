package service

import (
	"context"
	"encoding/base64"
	"errors"
	"log/slog"
	"time"

	"github.com/LaLanMo/muxagent/relay/internal/domain"
	"github.com/LaLanMo/muxagent/relay/internal/infra/crypto"
	"github.com/LaLanMo/muxagent/relay/internal/logging"
	"github.com/LaLanMo/muxagent/relay/internal/repository"
	"github.com/google/uuid"
)

type KeyringService interface {
	GetKeyringState(ctx context.Context, masterID uuid.UUID) (*KeyringState, error)
	GetKeyringUpdates(ctx context.Context, masterID uuid.UUID, fromSeq int, limit int) ([]domain.KeyringUpdate, error)
	UpdateKeyring(ctx context.Context, masterID uuid.UUID, input KeyringUpdateInput) error
}

type KeyringServiceImpl struct {
	masterIdentities repository.MasterIdentityRepository
	masterKeys       repository.MasterKeyRepository
	keyringUpdates   repository.KeyringUpdateRepository
	txRunner         repository.TxRunner
}

func NewKeyringService(
	masterIdentities repository.MasterIdentityRepository,
	masterKeys repository.MasterKeyRepository,
	keyringUpdates repository.KeyringUpdateRepository,
	txRunner repository.TxRunner,
) KeyringService {
	return &KeyringServiceImpl{
		masterIdentities: masterIdentities,
		masterKeys:       masterKeys,
		keyringUpdates:   keyringUpdates,
		txRunner:         txRunner,
	}
}

func (s *KeyringServiceImpl) GetKeyringState(ctx context.Context, masterID uuid.UUID) (*KeyringState, error) {
	identity, err := s.masterIdentities.FindByID(ctx, masterID)
	if err != nil {
		if errors.Is(err, repository.ErrMasterIdentityNotFound) {
			return nil, ErrMasterIdentityNotFound
		}
		return nil, err
	}
	keys, err := s.masterKeys.ListByMasterID(ctx, masterID)
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

func (s *KeyringServiceImpl) GetKeyringUpdates(ctx context.Context, masterID uuid.UUID, fromSeq int, limit int) ([]domain.KeyringUpdate, error) {
	if _, err := s.masterIdentities.FindByID(ctx, masterID); err != nil {
		if errors.Is(err, repository.ErrMasterIdentityNotFound) {
			return nil, ErrMasterIdentityNotFound
		}
		return nil, err
	}
	return s.keyringUpdates.ListByMasterIDFromSeq(ctx, masterID, fromSeq, limit)
}

func (s *KeyringServiceImpl) UpdateKeyring(ctx context.Context, masterID uuid.UUID, input KeyringUpdateInput) error {
	return s.txRunner.InTx(ctx, func(repos repository.TxRepositories) error {
		baseAttrs := []slog.Attr{
			slog.String("master_id", masterID.String()),
		}
		if input.SignerMasterSignKeyFingerprint != "" {
			baseAttrs = append(baseAttrs, slog.String("master_sign_key_fingerprint", input.SignerMasterSignKeyFingerprint))
		}
		reject := func(reasonErr error, attrs ...slog.Attr) error {
			logAttrs := append([]slog.Attr{}, baseAttrs...)
			logAttrs = append(logAttrs, attrs...)
			logging.Audit(
				ctx,
				slog.LevelWarn,
				logging.EventKeyringUpdateRejected,
				logging.ResultRejected,
				reasonErr.Error(),
				logAttrs...,
			)
			return reasonErr
		}

		if input.Action != KeyringActionAdd && input.Action != KeyringActionRevoke {
			return reject(ErrInvalidAction)
		}
		identity, err := repos.MasterIdentities.FindByIDForUpdate(ctx, masterID)
		if err != nil {
			if errors.Is(err, repository.ErrMasterIdentityNotFound) {
				return reject(ErrMasterIdentityNotFound)
			}
			return err
		}

		// Keyring head is the latest update hash; seq starts at 1 and increments by 1.
		targetSignPubB64 := base64.StdEncoding.EncodeToString(input.TargetMasterSignPub)
		targetEncPubB64 := base64.StdEncoding.EncodeToString(input.TargetMasterEncPub)
		updateMsg := crypto.BuildKeyringUpdateMessage(crypto.KeyringUpdatePayload{
			MasterID:                       input.MasterID,
			Seq:                            input.Seq,
			PrevHash:                       input.PrevHash,
			Action:                         string(input.Action),
			TargetMasterSignPub:            targetSignPubB64,
			TargetMasterEncPub:             targetEncPubB64,
			SignerMasterSignKeyFingerprint: input.SignerMasterSignKeyFingerprint,
		})

		if input.Seq != identity.KeyringSeq+1 || input.PrevHash != identity.KeyringHeadHash {
			return reject(ErrKeyringUpdateConflict)
		}

		signerKey, err := repos.MasterKeys.FindByMasterAndFingerprint(ctx, masterID, input.SignerMasterSignKeyFingerprint)
		if err != nil {
			if errors.Is(err, repository.ErrMasterKeyNotFound) {
				return reject(ErrSignerMasterKeyNotFound)
			}
			return err
		}

		if signerKey.RevokedAt != nil {
			return reject(ErrSignerMasterKeyNotFound)
		}

		if !crypto.VerifySignature(signerKey.MasterSignPub, []byte(updateMsg), input.Signature) {
			return reject(ErrInvalidKeyringUpdateSignature)
		}

		updateHash := crypto.HashBytes([]byte(updateMsg))
		update := &domain.KeyringUpdate{
			ID:                             uuid.New(),
			MasterID:                       masterID,
			Seq:                            input.Seq,
			PrevHash:                       input.PrevHash,
			UpdateHash:                     updateHash,
			Action:                         string(input.Action),
			TargetMasterSignKeyFingerprint: crypto.HashKeyFingerprint(input.TargetMasterSignPub),
			TargetMasterSignPub:            input.TargetMasterSignPub,
			TargetMasterEncPub:             input.TargetMasterEncPub,
			SignerMasterSignKeyFingerprint: input.SignerMasterSignKeyFingerprint,
			Signature:                      input.Signature,
		}
		if err := repos.KeyringUpdates.Create(ctx, update); err != nil {
			if errors.Is(err, repository.ErrDuplicateKey) {
				return reject(ErrKeyringUpdateConflict)
			}
			return err
		}

		if input.Action == KeyringActionAdd {
			fingerprint := crypto.HashKeyFingerprint(input.TargetMasterSignPub)
			if _, err := repos.MasterKeys.FindByFingerprint(ctx, fingerprint); err == nil {
				return reject(ErrMasterKeyAlreadyExists)
			} else if !errors.Is(err, repository.ErrMasterKeyNotFound) {
				return err
			}
			masterKey := &domain.MasterKey{
				ID:                              uuid.New(),
				MasterID:                        masterID,
				MasterSignKeyFingerprint:        fingerprint,
				MasterSignPub:                   input.TargetMasterSignPub,
				MasterEncPub:                    input.TargetMasterEncPub,
				AddedByMasterSignKeyFingerprint: &input.SignerMasterSignKeyFingerprint,
				KeyringSeqAdded:                 input.Seq,
			}
			if err := repos.MasterKeys.Create(ctx, masterKey); err != nil {
				return err
			}
		} else {
			fingerprint := crypto.HashKeyFingerprint(input.TargetMasterSignPub)
			if _, err := repos.MasterKeys.FindByMasterAndFingerprint(ctx, masterID, fingerprint); err != nil {
				if errors.Is(err, repository.ErrMasterKeyNotFound) {
					return reject(ErrMasterKeyNotFoundForRevoke)
				}
				return err
			}
			if err := repos.MasterKeys.Revoke(ctx, masterID, fingerprint, time.Now()); err != nil {
				return err
			}
		}

		if err := repos.MasterIdentities.UpdateKeyringState(ctx, masterID, input.Seq, updateHash); err != nil {
			return err
		}
		logging.Audit(
			ctx,
			slog.LevelInfo,
			logging.EventKeyringUpdateApplied,
			logging.ResultSuccess,
			"",
			baseAttrs...,
		)
		return nil
	})
}
