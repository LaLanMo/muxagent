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
	wire.FieldsOf(new(*testDBBundle), "DB", "Cleanup"),
	initTestRelaySigningKey,
	initTestConfig,
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
	ioc.InitWSServiceConfig,
)

var testHandlerSet = wire.NewSet(
	initTestAuthHandler,
	ioc.InitKeyringHandler,
	ioc.InitWSHandler,
	ioc.InitDeviceHandler,
	ioc.InitWSConnLimiter,
	ioc.InitTokenAuthMiddleware,
)

// Use production SetupRouter so rate-limit middleware and SetTrustedProxies
// validation are exercised by integration tests.
var testRouterSet = wire.NewSet(
	ioc.SetupRouter,
)
