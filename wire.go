//go:build wireinject

package main

import (
	"github.com/LaLanMo/muxagent-relay/internal/config"
	"github.com/LaLanMo/muxagent-relay/internal/ioc"
	"github.com/LaLanMo/muxagent-relay/internal/repository"
	"github.com/LaLanMo/muxagent-relay/internal/repository/dao"
	"github.com/LaLanMo/muxagent-relay/internal/service"
	"github.com/google/wire"
)

func InitApp(cfg *config.Config) (*App, error) {
	wire.Build(
		ioc.InitDB,
		ioc.InitRelaySigningKey,
		ioc.RelaySignPrivate,
		ioc.RelaySignPublic,
		ioc.InitAuthCleanup,
		ioc.InitFirebaseApp,
		ioc.InitFCMClient,

		daoSet,
		repositorySet,
		serviceSet,
		handlerSet,
		routerSet,

		wire.Struct(new(App), "*"),
	)
	return &App{}, nil
}

var daoSet = wire.NewSet(
	dao.NewGormAuthRequestDAO,
	dao.NewGormMasterIdentityDAO,
	dao.NewGormMasterKeyDAO,
	dao.NewGormMachineDAO,
	dao.NewGormKeyringUpdateDAO,
	dao.NewGormDeviceTokenDAO,
)

var repositorySet = wire.NewSet(
	repository.NewAuthRequestRepository,
	repository.NewMasterIdentityRepository,
	repository.NewMasterKeyRepository,
	repository.NewMachineRepository,
	repository.NewKeyringUpdateRepository,
	repository.NewDeviceTokenRepository,
	repository.NewTxRunner,
)

var serviceSet = wire.NewSet(
	service.NewWSHub,
	service.NewSessionRegistry,
	service.NewTokenService,
	service.NewWSService,
	service.NewAuthService,
	service.NewKeyringService,
	service.NewPushService,
)

var handlerSet = wire.NewSet(
	ioc.InitAuthHandler,
	ioc.InitKeyringHandler,
	ioc.InitWSHandler,
	ioc.InitDeviceHandler,
)

var routerSet = wire.NewSet(
	ioc.SetupRouter,
)
