package dao

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Machine represents a paired CLI/daemon device.
type Machine struct {
	ID                        uuid.UUID `gorm:"type:uuid;primaryKey"`
	MasterID                  uuid.UUID `gorm:"type:uuid;index"`
	MachineSignKeyFingerprint string    `gorm:"uniqueIndex"` // fingerprint(machine_sign_pub)
	MachineSignPub            []byte    `gorm:"type:bytea"`
	MachineEncPub             []byte    `gorm:"type:bytea"`
	Hostname                  string
	CreatedAt                 time.Time `gorm:"autoCreateTime"`
	LastSeenAt                time.Time
	RevokedAt                 *time.Time
}

type MachineDAO interface {
	Create(ctx context.Context, machine *Machine) error
	FindByID(ctx context.Context, id uuid.UUID) (*Machine, error)
	UpdateLastSeenAndHostname(ctx context.Context, id uuid.UUID, lastSeen time.Time, hostname string) error
}

type gormMachineDAO struct {
	db *gorm.DB
}

func NewGormMachineDAO(db *gorm.DB) MachineDAO {
	return &gormMachineDAO{db: db}
}

func (d *gormMachineDAO) Create(ctx context.Context, machine *Machine) error {
	return d.db.WithContext(ctx).Create(machine).Error
}

func (d *gormMachineDAO) FindByID(ctx context.Context, id uuid.UUID) (*Machine, error) {
	var out Machine
	if err := d.db.WithContext(ctx).First(&out, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrRecordNotFound
		}
		return nil, err
	}
	return &out, nil
}

func (d *gormMachineDAO) UpdateLastSeenAndHostname(ctx context.Context, id uuid.UUID, lastSeen time.Time, hostname string) error {
	return d.db.WithContext(ctx).
		Model(&Machine{}).
		Where("id = ?", id).
		Updates(map[string]any{"last_seen_at": lastSeen, "hostname": hostname}).Error
}
