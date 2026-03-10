package dao

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// AuthRequest represents a pending device pairing request.
type AuthRequest struct {
	ID                                 uuid.UUID `gorm:"type:uuid;primaryKey"`
	MachineID                          uuid.UUID `gorm:"type:uuid;index"`
	MachineSignPub                     []byte    `gorm:"type:bytea"`
	MachineEncPub                      []byte    `gorm:"type:bytea"`
	Hostname                           string
	CreatedAt                          time.Time `gorm:"autoCreateTime"`
	ExpiresAt                          time.Time `gorm:"not null"`
	RelayChallenge                     []byte    `gorm:"type:bytea"`
	PollToken                          []byte    `gorm:"type:bytea"`
	ApprovedAt                         *time.Time
	ApprovedByMasterSignKeyFingerprint *string
	ApprovalSignature                  []byte `gorm:"type:bytea"`
}

type AuthRequestDAO interface {
	Create(ctx context.Context, req *AuthRequest) error
	FindByID(ctx context.Context, id uuid.UUID) (*AuthRequest, error)
	FindByIDForUpdate(ctx context.Context, id uuid.UUID) (*AuthRequest, error)
	Update(ctx context.Context, req *AuthRequest) error
	DeleteByID(ctx context.Context, id uuid.UUID) error
	DeleteExpired(ctx context.Context, cutoff time.Time) error
	NullifyExpiredPollTokens(ctx context.Context, cutoff time.Time) error
}

type gormAuthRequestDAO struct {
	db *gorm.DB
}

func NewGormAuthRequestDAO(db *gorm.DB) AuthRequestDAO {
	return &gormAuthRequestDAO{db: db}
}

func (d *gormAuthRequestDAO) Create(ctx context.Context, req *AuthRequest) error {
	return d.db.WithContext(ctx).Create(req).Error
}

func (d *gormAuthRequestDAO) FindByID(ctx context.Context, id uuid.UUID) (*AuthRequest, error) {
	var out AuthRequest
	if err := d.db.WithContext(ctx).First(&out, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrRecordNotFound
		}
		return nil, err
	}
	return &out, nil
}

func (d *gormAuthRequestDAO) FindByIDForUpdate(ctx context.Context, id uuid.UUID) (*AuthRequest, error) {
	var out AuthRequest
	if err := d.db.WithContext(ctx).
		Clauses(clause.Locking{Strength: "UPDATE"}).
		First(&out, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrRecordNotFound
		}
		return nil, err
	}
	return &out, nil
}

func (d *gormAuthRequestDAO) Update(ctx context.Context, req *AuthRequest) error {
	return d.db.WithContext(ctx).Save(req).Error
}

func (d *gormAuthRequestDAO) DeleteByID(ctx context.Context, id uuid.UUID) error {
	return d.db.WithContext(ctx).Delete(&AuthRequest{}, "id = ?", id).Error
}

func (d *gormAuthRequestDAO) DeleteExpired(ctx context.Context, cutoff time.Time) error {
	return d.db.WithContext(ctx).Delete(&AuthRequest{}, "expires_at < ? AND approved_at IS NULL", cutoff).Error
}

func (d *gormAuthRequestDAO) NullifyExpiredPollTokens(ctx context.Context, cutoff time.Time) error {
	return d.db.WithContext(ctx).Model(&AuthRequest{}).
		Where("approved_at IS NOT NULL AND expires_at < ? AND poll_token IS NOT NULL", cutoff).
		Update("poll_token", nil).Error
}
