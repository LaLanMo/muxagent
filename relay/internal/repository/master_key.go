package repository

import (
	"context"
	"errors"
	"time"

	"github.com/LaLanMo/muxagent-relay/internal/domain"
	"github.com/LaLanMo/muxagent-relay/internal/repository/dao"
	"github.com/google/uuid"
)

type MasterKeyRepository interface {
	Create(ctx context.Context, key *domain.MasterKey) error
	FindByFingerprint(ctx context.Context, fingerprint string) (domain.MasterKey, error)
	FindByMasterAndFingerprint(ctx context.Context, masterID uuid.UUID, fingerprint string) (domain.MasterKey, error)
	ListByMasterID(ctx context.Context, masterID uuid.UUID) ([]domain.MasterKey, error)
	Revoke(ctx context.Context, masterID uuid.UUID, fingerprint string, revokedAt time.Time) error
}

type masterKeyRepository struct {
	dao dao.MasterKeyDAO
}

func NewMasterKeyRepository(dao dao.MasterKeyDAO) MasterKeyRepository {
	return &masterKeyRepository{dao: dao}
}

func (r *masterKeyRepository) Create(ctx context.Context, key *domain.MasterKey) error {
	return r.dao.Create(ctx, toDAOMasterKey(*key))
}

func (r *masterKeyRepository) FindByFingerprint(ctx context.Context, fingerprint string) (domain.MasterKey, error) {
	key, err := r.dao.FindByFingerprint(ctx, fingerprint)
	if err != nil {
		if errors.Is(err, dao.ErrRecordNotFound) {
			return domain.MasterKey{}, ErrMasterKeyNotFound
		}
		return domain.MasterKey{}, err
	}
	return toDomainMasterKey(*key), nil
}

func (r *masterKeyRepository) FindByMasterAndFingerprint(ctx context.Context, masterID uuid.UUID, fingerprint string) (domain.MasterKey, error) {
	key, err := r.dao.FindByMasterAndFingerprint(ctx, masterID, fingerprint)
	if err != nil {
		if errors.Is(err, dao.ErrRecordNotFound) {
			return domain.MasterKey{}, ErrMasterKeyNotFound
		}
		return domain.MasterKey{}, err
	}
	return toDomainMasterKey(*key), nil
}

func (r *masterKeyRepository) ListByMasterID(ctx context.Context, masterID uuid.UUID) ([]domain.MasterKey, error) {
	keys, err := r.dao.ListByMasterID(ctx, masterID)
	if err != nil {
		return nil, err
	}
	out := make([]domain.MasterKey, 0, len(keys))
	for _, key := range keys {
		out = append(out, toDomainMasterKey(key))
	}
	return out, nil
}

func (r *masterKeyRepository) Revoke(ctx context.Context, masterID uuid.UUID, fingerprint string, revokedAt time.Time) error {
	return r.dao.Revoke(ctx, masterID, fingerprint, revokedAt)
}

func toDomainMasterKey(key dao.MasterKey) domain.MasterKey {
	return domain.MasterKey{
		ID:                              key.ID,
		MasterID:                        key.MasterID,
		MasterSignKeyFingerprint:        key.MasterSignKeyFingerprint,
		MasterSignPub:                   key.MasterSignPub,
		MasterEncPub:                    key.MasterEncPub,
		CreatedAt:                       key.CreatedAt,
		RevokedAt:                       key.RevokedAt,
		AddedByMasterSignKeyFingerprint: key.AddedByMasterSignKeyFingerprint,
		KeyringSeqAdded:                 key.KeyringSeqAdded,
	}
}

func toDAOMasterKey(key domain.MasterKey) *dao.MasterKey {
	return &dao.MasterKey{
		ID:                              key.ID,
		MasterID:                        key.MasterID,
		MasterSignKeyFingerprint:        key.MasterSignKeyFingerprint,
		MasterSignPub:                   key.MasterSignPub,
		MasterEncPub:                    key.MasterEncPub,
		CreatedAt:                       key.CreatedAt,
		RevokedAt:                       key.RevokedAt,
		AddedByMasterSignKeyFingerprint: key.AddedByMasterSignKeyFingerprint,
		KeyringSeqAdded:                 key.KeyringSeqAdded,
	}
}
