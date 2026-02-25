package dao

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// MasterIdentity represents a long-lived identity (keyring).
type MasterIdentity struct {
	ID              uuid.UUID `gorm:"type:uuid;primaryKey"`
	CreatedAt       time.Time `gorm:"autoCreateTime"`
	RevokedAt       *time.Time
	KeyringSeq      int
	KeyringHeadHash string
}

type MasterIdentityDAO interface {
	Create(ctx context.Context, identity *MasterIdentity) error
	FindByID(ctx context.Context, id uuid.UUID) (*MasterIdentity, error)
	UpdateKeyringState(ctx context.Context, id uuid.UUID, seq int, headHash string) error
}

type gormMasterIdentityDAO struct {
	db *gorm.DB
}

func NewGormMasterIdentityDAO(db *gorm.DB) MasterIdentityDAO {
	return &gormMasterIdentityDAO{db: db}
}

func (d *gormMasterIdentityDAO) Create(ctx context.Context, identity *MasterIdentity) error {
	return d.db.WithContext(ctx).Create(identity).Error
}

func (d *gormMasterIdentityDAO) FindByID(ctx context.Context, id uuid.UUID) (*MasterIdentity, error) {
	var out MasterIdentity
	if err := d.db.WithContext(ctx).First(&out, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrRecordNotFound
		}
		return nil, err
	}
	return &out, nil
}

func (d *gormMasterIdentityDAO) UpdateKeyringState(ctx context.Context, id uuid.UUID, seq int, headHash string) error {
	return d.db.WithContext(ctx).Model(&MasterIdentity{}).
		Where("id = ?", id).
		Updates(map[string]any{"keyring_seq": seq, "keyring_head_hash": headHash}).Error
}
