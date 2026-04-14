package repository

import (
	"context"
	"errors"
	"time"

	"github.com/LaLanMo/muxagent-relay/internal/domain"
	"github.com/LaLanMo/muxagent-relay/internal/repository/dao"
	"github.com/google/uuid"
)

type MachineRepository interface {
	Create(ctx context.Context, machine *domain.Machine) error
	FindByID(ctx context.Context, id uuid.UUID) (domain.Machine, error)
	UpdateLastSeenAndHostname(ctx context.Context, id uuid.UUID, lastSeen time.Time, hostname string) error
}

type machineRepository struct {
	dao dao.MachineDAO
}

func NewMachineRepository(dao dao.MachineDAO) MachineRepository {
	return &machineRepository{dao: dao}
}

func (r *machineRepository) Create(ctx context.Context, machine *domain.Machine) error {
	return r.dao.Create(ctx, toDAOMachine(*machine))
}

func (r *machineRepository) FindByID(ctx context.Context, id uuid.UUID) (domain.Machine, error) {
	machine, err := r.dao.FindByID(ctx, id)
	if err != nil {
		if errors.Is(err, dao.ErrRecordNotFound) {
			return domain.Machine{}, ErrMachineNotFound
		}
		return domain.Machine{}, err
	}
	return toDomainMachine(*machine), nil
}

func (r *machineRepository) UpdateLastSeenAndHostname(ctx context.Context, id uuid.UUID, lastSeen time.Time, hostname string) error {
	return r.dao.UpdateLastSeenAndHostname(ctx, id, lastSeen, hostname)
}

func toDomainMachine(machine dao.Machine) domain.Machine {
	return domain.Machine{
		ID:                        machine.ID,
		MasterID:                  machine.MasterID,
		MachineSignKeyFingerprint: machine.MachineSignKeyFingerprint,
		MachineSignPub:            machine.MachineSignPub,
		MachineEncPub:             machine.MachineEncPub,
		Hostname:                  machine.Hostname,
		CreatedAt:                 machine.CreatedAt,
		LastSeenAt:                machine.LastSeenAt,
		RevokedAt:                 machine.RevokedAt,
	}
}

func toDAOMachine(machine domain.Machine) *dao.Machine {
	return &dao.Machine{
		ID:                        machine.ID,
		MasterID:                  machine.MasterID,
		MachineSignKeyFingerprint: machine.MachineSignKeyFingerprint,
		MachineSignPub:            machine.MachineSignPub,
		MachineEncPub:             machine.MachineEncPub,
		Hostname:                  machine.Hostname,
		CreatedAt:                 machine.CreatedAt,
		LastSeenAt:                machine.LastSeenAt,
		RevokedAt:                 machine.RevokedAt,
	}
}
