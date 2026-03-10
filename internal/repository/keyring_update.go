package repository

import (
	"context"
	"errors"

	"github.com/LaLanMo/muxagent-relay/internal/domain"
	"github.com/LaLanMo/muxagent-relay/internal/repository/dao"
	"github.com/google/uuid"
)

type KeyringUpdateRepository interface {
	Create(ctx context.Context, update *domain.KeyringUpdate) error
	ListByMasterIDFromSeq(ctx context.Context, masterID uuid.UUID, fromSeq int, limit int) ([]domain.KeyringUpdate, error)
}

type keyringUpdateRepository struct {
	dao dao.KeyringUpdateDAO
}

func NewKeyringUpdateRepository(dao dao.KeyringUpdateDAO) KeyringUpdateRepository {
	return &keyringUpdateRepository{dao: dao}
}

func (r *keyringUpdateRepository) Create(ctx context.Context, update *domain.KeyringUpdate) error {
	if err := r.dao.Create(ctx, toDAOKeyringUpdate(*update)); err != nil {
		if errors.Is(err, dao.ErrDuplicateKey) {
			return ErrDuplicateKey
		}
		return err
	}
	return nil
}

func (r *keyringUpdateRepository) ListByMasterIDFromSeq(ctx context.Context, masterID uuid.UUID, fromSeq int, limit int) ([]domain.KeyringUpdate, error) {
	updates, err := r.dao.ListByMasterIDFromSeq(ctx, masterID, fromSeq, limit)
	if err != nil {
		return nil, err
	}
	out := make([]domain.KeyringUpdate, 0, len(updates))
	for _, update := range updates {
		out = append(out, toDomainKeyringUpdate(update))
	}
	return out, nil
}

func toDAOKeyringUpdate(update domain.KeyringUpdate) *dao.KeyringUpdate {
	return &dao.KeyringUpdate{
		ID:                             update.ID,
		MasterID:                       update.MasterID,
		Seq:                            update.Seq,
		PrevHash:                       update.PrevHash,
		UpdateHash:                     update.UpdateHash,
		Action:                         update.Action,
		TargetMasterSignKeyFingerprint: update.TargetMasterSignKeyFingerprint,
		TargetMasterSignPub:            update.TargetMasterSignPub,
		TargetMasterEncPub:             update.TargetMasterEncPub,
		SignerMasterSignKeyFingerprint: update.SignerMasterSignKeyFingerprint,
		CreatedAt:                      update.CreatedAt,
		Signature:                      update.Signature,
	}
}

func toDomainKeyringUpdate(update dao.KeyringUpdate) domain.KeyringUpdate {
	return domain.KeyringUpdate{
		ID:                             update.ID,
		MasterID:                       update.MasterID,
		Seq:                            update.Seq,
		PrevHash:                       update.PrevHash,
		UpdateHash:                     update.UpdateHash,
		Action:                         update.Action,
		TargetMasterSignKeyFingerprint: update.TargetMasterSignKeyFingerprint,
		TargetMasterSignPub:            update.TargetMasterSignPub,
		TargetMasterEncPub:             update.TargetMasterEncPub,
		SignerMasterSignKeyFingerprint: update.SignerMasterSignKeyFingerprint,
		CreatedAt:                      update.CreatedAt,
		Signature:                      update.Signature,
	}
}
