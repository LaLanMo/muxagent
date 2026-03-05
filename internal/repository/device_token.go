package repository

import (
	"context"

	"github.com/LaLanMo/muxagent-relay/internal/domain"
	"github.com/LaLanMo/muxagent-relay/internal/repository/dao"
	"github.com/google/uuid"
)

type DeviceTokenRepository interface {
	Upsert(ctx context.Context, token *domain.DeviceToken) error
	DeleteByToken(ctx context.Context, token string) error
	DeleteByMasterAndToken(ctx context.Context, masterID uuid.UUID, token string) error
	FindByMasterID(ctx context.Context, masterID uuid.UUID) ([]domain.DeviceToken, error)
}

type deviceTokenRepository struct {
	dao dao.DeviceTokenDAO
}

func NewDeviceTokenRepository(dao dao.DeviceTokenDAO) DeviceTokenRepository {
	return &deviceTokenRepository{dao: dao}
}

func (r *deviceTokenRepository) Upsert(ctx context.Context, token *domain.DeviceToken) error {
	return r.dao.Upsert(ctx, toDAODeviceToken(*token))
}

func (r *deviceTokenRepository) DeleteByToken(ctx context.Context, token string) error {
	return r.dao.DeleteByToken(ctx, token)
}

func (r *deviceTokenRepository) DeleteByMasterAndToken(ctx context.Context, masterID uuid.UUID, token string) error {
	return r.dao.DeleteByMasterAndToken(ctx, masterID, token)
}

func (r *deviceTokenRepository) FindByMasterID(ctx context.Context, masterID uuid.UUID) ([]domain.DeviceToken, error) {
	tokens, err := r.dao.FindByMasterID(ctx, masterID)
	if err != nil {
		return nil, err
	}
	result := make([]domain.DeviceToken, len(tokens))
	for i, t := range tokens {
		result[i] = toDomainDeviceToken(t)
	}
	return result, nil
}

func toDomainDeviceToken(t dao.DeviceToken) domain.DeviceToken {
	return domain.DeviceToken{
		ID:        t.ID,
		MasterID:  t.MasterID,
		Token:     t.Token,
		Platform:  t.Platform,
		CreatedAt: t.CreatedAt,
		UpdatedAt: t.UpdatedAt,
	}
}

func toDAODeviceToken(t domain.DeviceToken) *dao.DeviceToken {
	return &dao.DeviceToken{
		ID:       t.ID,
		MasterID: t.MasterID,
		Token:    t.Token,
		Platform: t.Platform,
	}
}
