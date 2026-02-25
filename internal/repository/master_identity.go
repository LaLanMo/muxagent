package repository

import (
	"context"
	"errors"

	"github.com/LaLanMo/muxagent-relay/internal/domain"
	"github.com/LaLanMo/muxagent-relay/internal/repository/dao"
	"github.com/google/uuid"
)

type MasterIdentityRepository interface {
	Create(ctx context.Context, identity *domain.MasterIdentity) error
	FindByID(ctx context.Context, id uuid.UUID) (domain.MasterIdentity, error)
	UpdateKeyringState(ctx context.Context, id uuid.UUID, seq int, headHash string) error
}

type masterIdentityRepository struct {
	dao dao.MasterIdentityDAO
}

func NewMasterIdentityRepository(dao dao.MasterIdentityDAO) MasterIdentityRepository {
	return &masterIdentityRepository{dao: dao}
}

func (r *masterIdentityRepository) Create(ctx context.Context, identity *domain.MasterIdentity) error {
	return r.dao.Create(ctx, toDAOMasterIdentity(*identity))
}

func (r *masterIdentityRepository) FindByID(ctx context.Context, id uuid.UUID) (domain.MasterIdentity, error) {
	identity, err := r.dao.FindByID(ctx, id)
	if err != nil {
		if errors.Is(err, dao.ErrRecordNotFound) {
			return domain.MasterIdentity{}, ErrMasterIdentityNotFound
		}
		return domain.MasterIdentity{}, err
	}
	return toDomainMasterIdentity(*identity), nil
}

func (r *masterIdentityRepository) UpdateKeyringState(ctx context.Context, id uuid.UUID, seq int, headHash string) error {
	return r.dao.UpdateKeyringState(ctx, id, seq, headHash)
}

func toDomainMasterIdentity(identity dao.MasterIdentity) domain.MasterIdentity {
	return domain.MasterIdentity{
		ID:              identity.ID,
		CreatedAt:       identity.CreatedAt,
		RevokedAt:       identity.RevokedAt,
		KeyringSeq:      identity.KeyringSeq,
		KeyringHeadHash: identity.KeyringHeadHash,
	}
}

func toDAOMasterIdentity(identity domain.MasterIdentity) *dao.MasterIdentity {
	return &dao.MasterIdentity{
		ID:              identity.ID,
		CreatedAt:       identity.CreatedAt,
		RevokedAt:       identity.RevokedAt,
		KeyringSeq:      identity.KeyringSeq,
		KeyringHeadHash: identity.KeyringHeadHash,
	}
}
