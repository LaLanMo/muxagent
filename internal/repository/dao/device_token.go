package dao

import (
	"context"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type DeviceToken struct {
	ID        uuid.UUID `gorm:"type:uuid;primaryKey"`
	MasterID  uuid.UUID `gorm:"type:uuid;index:idx_device_token_master"`
	Token     string    `gorm:"uniqueIndex"`
	Platform  string
	CreatedAt time.Time
	UpdatedAt time.Time
}

type DeviceTokenDAO interface {
	Upsert(ctx context.Context, token *DeviceToken) error
	DeleteByToken(ctx context.Context, token string) error
	DeleteByMasterAndToken(ctx context.Context, masterID uuid.UUID, token string) error
	FindByMasterID(ctx context.Context, masterID uuid.UUID) ([]DeviceToken, error)
}

type gormDeviceTokenDAO struct {
	db *gorm.DB
}

func NewGormDeviceTokenDAO(db *gorm.DB) DeviceTokenDAO {
	return &gormDeviceTokenDAO{db: db}
}

func (d *gormDeviceTokenDAO) Upsert(ctx context.Context, token *DeviceToken) error {
	return d.db.WithContext(ctx).
		Clauses(clause.OnConflict{
			Columns:   []clause.Column{{Name: "token"}},
			DoUpdates: clause.AssignmentColumns([]string{"master_id", "platform", "updated_at"}),
		}).Create(token).Error
}

func (d *gormDeviceTokenDAO) DeleteByToken(ctx context.Context, token string) error {
	return d.db.WithContext(ctx).Where("token = ?", token).Delete(&DeviceToken{}).Error
}

func (d *gormDeviceTokenDAO) DeleteByMasterAndToken(ctx context.Context, masterID uuid.UUID, token string) error {
	return d.db.WithContext(ctx).Where("master_id = ? AND token = ?", masterID, token).Delete(&DeviceToken{}).Error
}

func (d *gormDeviceTokenDAO) FindByMasterID(ctx context.Context, masterID uuid.UUID) ([]DeviceToken, error) {
	var tokens []DeviceToken
	if err := d.db.WithContext(ctx).Where("master_id = ?", masterID).Find(&tokens).Error; err != nil {
		return nil, err
	}
	return tokens, nil
}
