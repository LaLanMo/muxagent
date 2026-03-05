//go:build wireinject

package intergration

import (
	"github.com/LaLanMo/muxagent-relay/internal/ioc"
	"github.com/LaLanMo/muxagent-relay/internal/repository"
	"github.com/LaLanMo/muxagent-relay/internal/repository/dao"
	"github.com/LaLanMo/muxagent-relay/internal/service"
	"github.com/google/wire"
)

func InitTestContainer() (*testContainer, error) {
	wire.Build(
		testInfraSet,
		testDaoSet,
		testRepositorySet,
		testServiceSet,
		testHandlerSet,
		testRouterSet,
		wire.Struct(new(testContainer), "*"),
	)
	return &testContainer{}, nil
}

var testInfraSet = wire.NewSet(
	initTestDB,
	initTestRelaySigningKey,
	ioc.RelaySignPrivate,
	ioc.RelaySignPublic,
)

var testDaoSet = wire.NewSet(
	dao.NewGormAuthRequestDAO,
	dao.NewGormMasterIdentityDAO,
	dao.NewGormMasterKeyDAO,
	dao.NewGormMachineDAO,
	dao.NewGormKeyringUpdateDAO,
	dao.NewGormDeviceTokenDAO,
)

var testRepositorySet = wire.NewSet(
	repository.NewAuthRequestRepository,
	repository.NewMasterIdentityRepository,
	repository.NewMasterKeyRepository,
	repository.NewMachineRepository,
	repository.NewKeyringUpdateRepository,
	repository.NewDeviceTokenRepository,
	repository.NewTxRunner,
)

var testServiceSet = wire.NewSet(
	service.NewWSHub,
	service.NewSessionRegistry,
	service.NewTokenService,
	service.NewWSService,
	service.NewAuthService,
	service.NewKeyringService,
	initTestNilFCMClient,
	service.NewPushService,
)

var testHandlerSet = wire.NewSet(
	initTestAuthHandler,
	ioc.InitKeyringHandler,
	ioc.InitWSHandler,
)

var testRouterSet = wire.NewSet(
	initTestRouter,
)
