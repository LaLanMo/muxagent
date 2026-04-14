package dao

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// MasterKey represents a master device keypair.
type MasterKey struct {
	ID                              uuid.UUID `gorm:"type:uuid;primaryKey"`
	MasterID                        uuid.UUID `gorm:"type:uuid;index"`
	MasterSignKeyFingerprint        string    `gorm:"uniqueIndex"` // fingerprint(master_sign_pub)
	MasterSignPub                   []byte    `gorm:"type:bytea"`
	MasterEncPub                    []byte    `gorm:"type:bytea"`
	CreatedAt                       time.Time `gorm:"autoCreateTime"`
	RevokedAt                       *time.Time
	AddedByMasterSignKeyFingerprint *string
	KeyringSeqAdded                 int
}

type MasterKeyDAO interface {
	Create(ctx context.Context, key *MasterKey) error
	FindByFingerprint(ctx context.Context, fingerprint string) (*MasterKey, error)
	FindByMasterAndFingerprint(ctx context.Context, masterID uuid.UUID, fingerprint string) (*MasterKey, error)
	ListByMasterID(ctx context.Context, masterID uuid.UUID) ([]MasterKey, error)
	Revoke(ctx context.Context, masterID uuid.UUID, fingerprint string, revokedAt time.Time) error
}

type gormMasterKeyDAO struct {
	db *gorm.DB
}

func NewGormMasterKeyDAO(db *gorm.DB) MasterKeyDAO {
	return &gormMasterKeyDAO{db: db}
}

func (d *gormMasterKeyDAO) Create(ctx context.Context, key *MasterKey) error {
	return d.db.WithContext(ctx).Create(key).Error
}

func (d *gormMasterKeyDAO) FindByFingerprint(ctx context.Context, fingerprint string) (*MasterKey, error) {
	var out MasterKey
	if err := d.db.WithContext(ctx).First(&out, "master_sign_key_fingerprint = ?", fingerprint).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrRecordNotFound
		}
		return nil, err
	}
	return &out, nil
}

func (d *gormMasterKeyDAO) FindByMasterAndFingerprint(ctx context.Context, masterID uuid.UUID, fingerprint string) (*MasterKey, error) {
	var out MasterKey
	if err := d.db.WithContext(ctx).
		First(&out, "master_id = ? AND master_sign_key_fingerprint = ?", masterID, fingerprint).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrRecordNotFound
		}
		return nil, err
	}
	return &out, nil
}

func (d *gormMasterKeyDAO) ListByMasterID(ctx context.Context, masterID uuid.UUID) ([]MasterKey, error) {
	var out []MasterKey
	if err := d.db.WithContext(ctx).
		Where("master_id = ?", masterID).
		Order("created_at asc").
		Find(&out).Error; err != nil {
		return nil, err
	}
	return out, nil
}

func (d *gormMasterKeyDAO) Revoke(ctx context.Context, masterID uuid.UUID, fingerprint string, revokedAt time.Time) error {
	return d.db.WithContext(ctx).
		Model(&MasterKey{}).
		Where("master_id = ? AND master_sign_key_fingerprint = ? AND revoked_at IS NULL", masterID, fingerprint).
		Updates(map[string]any{"revoked_at": revokedAt}).Error
}
