package repository

import (
	"context"
	"errors"

	"github.com/LaLanMo/muxagent/relay/internal/repository/dao"
	"gorm.io/gorm"
)

type TxRepositories struct {
	AuthRequests     AuthRequestRepository
	MasterIdentities MasterIdentityRepository
	MasterKeys       MasterKeyRepository
	Machines         MachineRepository
	KeyringUpdates   KeyringUpdateRepository
}

type TxRunner interface {
	InTx(ctx context.Context, fn func(repos TxRepositories) error) error
}

type gormTxRunner struct {
	db *gorm.DB
}

func NewTxRunner(db *gorm.DB) TxRunner {
	return &gormTxRunner{db: db}
}

func (r *gormTxRunner) InTx(ctx context.Context, fn func(repos TxRepositories) error) error {
	if r.db == nil {
		return errors.New("db is required")
	}
	if fn == nil {
		return nil
	}
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		repos := TxRepositories{
			AuthRequests:     NewAuthRequestRepository(dao.NewGormAuthRequestDAO(tx)),
			MasterIdentities: NewMasterIdentityRepository(dao.NewGormMasterIdentityDAO(tx)),
			MasterKeys:       NewMasterKeyRepository(dao.NewGormMasterKeyDAO(tx)),
			Machines:         NewMachineRepository(dao.NewGormMachineDAO(tx)),
			KeyringUpdates:   NewKeyringUpdateRepository(dao.NewGormKeyringUpdateDAO(tx)),
		}
		return fn(repos)
	})
}
