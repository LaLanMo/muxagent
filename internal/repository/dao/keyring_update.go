package dao

import (
	"context"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// KeyringUpdate is an append-only signed update for a MasterIdentity keyring.
type KeyringUpdate struct {
	ID                             uuid.UUID `gorm:"type:uuid;primaryKey"`
	MasterID                       uuid.UUID `gorm:"type:uuid;index"`
	Seq                            int
	PrevHash                       string
	UpdateHash                     string
	Action                         string
	TargetMasterSignKeyFingerprint string
	TargetMasterSignPub            []byte `gorm:"type:bytea"`
	TargetMasterEncPub             []byte `gorm:"type:bytea"`
	SignerMasterSignKeyFingerprint string
	CreatedAt                      time.Time `gorm:"autoCreateTime"`
	Signature                      []byte    `gorm:"type:bytea"`
}

type KeyringUpdateDAO interface {
	Create(ctx context.Context, update *KeyringUpdate) error
	ListByMasterIDFromSeq(ctx context.Context, masterID uuid.UUID, fromSeq int, limit int) ([]KeyringUpdate, error)
}

type gormKeyringUpdateDAO struct {
	db *gorm.DB
}

func NewGormKeyringUpdateDAO(db *gorm.DB) KeyringUpdateDAO {
	return &gormKeyringUpdateDAO{db: db}
}

func (d *gormKeyringUpdateDAO) Create(ctx context.Context, update *KeyringUpdate) error {
	return d.db.WithContext(ctx).Create(update).Error
}

func (d *gormKeyringUpdateDAO) ListByMasterIDFromSeq(ctx context.Context, masterID uuid.UUID, fromSeq int, limit int) ([]KeyringUpdate, error) {
	var out []KeyringUpdate
	query := d.db.WithContext(ctx).
		Where("master_id = ? AND seq > ?", masterID, fromSeq).
		Order("seq ASC")
	if limit > 0 {
		query = query.Limit(limit)
	}
	if err := query.Find(&out).Error; err != nil {
		return nil, err
	}
	return out, nil
}
