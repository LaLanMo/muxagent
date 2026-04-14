package intergration

import (
	"crypto/ed25519"
	"crypto/rand"

	"firebase.google.com/go/v4/messaging"
	"github.com/LaLanMo/muxagent/relay/internal/api"
	"github.com/LaLanMo/muxagent/relay/internal/config"
	"github.com/LaLanMo/muxagent/relay/internal/ioc"
	"github.com/LaLanMo/muxagent/relay/internal/repository/dao"
	"github.com/LaLanMo/muxagent/relay/internal/service"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// testDBBundle bundles DB and its cleanup so Wire doesn't treat cleanup as
// a Wire cleanup function (which cannot fill struct fields).
type testDBBundle struct {
	DB      *gorm.DB
	Cleanup TestCleanup
}

func initTestDB() (*testDBBundle, error) {
	dbConn, err := gorm.Open(sqlite.Open("file::memory:?cache=shared&_busy_timeout=5000"), &gorm.Config{
		Logger:         logger.Default.LogMode(logger.Silent),
		TranslateError: true,
	})
	if err != nil {
		return nil, err
	}
	sqlDB, err := dbConn.DB()
	if err != nil {
		return nil, err
	}
	sqlDB.SetMaxOpenConns(5)
	sqlDB.SetMaxIdleConns(5)

	if err := dao.AutoMigrate(dbConn); err != nil {
		_ = sqlDB.Close()
		return nil, err
	}

	return &testDBBundle{
		DB: dbConn,
		Cleanup: TestCleanup(func() {
			_ = sqlDB.Close()
		}),
	}, nil
}

func initTestRelaySigningKey() (*ioc.RelaySigningKey, error) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return nil, err
	}
	return &ioc.RelaySigningKey{Private: priv, Public: pub}, nil
}

func initTestAuthHandler(auth service.AuthService) *api.AuthHandler {
	return api.NewAuthHandler(auth, "https://relay.test")
}

func initTestNilFCMClient() *messaging.Client {
	return nil
}

// initTestConfig returns a config with high rate limits so tests don't get
// throttled, while still exercising the production SetupRouter wiring.
func initTestConfig() *config.Config {
	return &config.Config{
		HTTP: config.HTTPConfig{
			ReadHeaderTimeoutSec: 5,
			ReadTimeoutSec:       15,
			WriteTimeoutSec:      30,
			IdleTimeoutSec:       60,
			MaxHeaderBytes:       16 * 1024,
			MaxJSONBodyBytes:     64 * 1024,
		},
		RateLimit: config.RateLimitConfig{
			AuthCreatePerIPPerMin:       1000,
			ReadPerIPPerMin:             1000,
			WritePerIPPerMin:            1000,
			WSUpgradePerIPPerMin:        1000,
			MaxWSConnsPerIP:             100,
			MaxWSConnsTotal:             1000,
			WSInboundBytesPerConnPerMin: 500 * 1024 * 1024,
			WSRegisterTimeoutSec:        30,
		},
	}
}
