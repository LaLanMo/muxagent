package intergration

import (
	"crypto/ed25519"
	"crypto/rand"

	"github.com/LaLanMo/muxagent-relay/internal/api"
	"github.com/LaLanMo/muxagent-relay/internal/ioc"
	"github.com/LaLanMo/muxagent-relay/internal/repository/dao"
	"github.com/LaLanMo/muxagent-relay/internal/service"
	"github.com/gin-gonic/gin"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func initTestDB() (*gorm.DB, func(), error) {
	dbConn, err := gorm.Open(sqlite.Open("file::memory:?cache=shared"), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		return nil, nil, err
	}
	sqlDB, err := dbConn.DB()
	if err != nil {
		return nil, nil, err
	}
	sqlDB.SetMaxOpenConns(5)
	sqlDB.SetMaxIdleConns(5)

	if err := dao.AutoMigrate(dbConn); err != nil {
		_ = sqlDB.Close()
		return nil, nil, err
	}

	return dbConn, func() {
		_ = sqlDB.Close()
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

func initTestRouter(authHandler *api.AuthHandler, keyringHandler *api.KeyringHandler, wsHandler *api.WSHandler) *gin.Engine {
	router := gin.New()
	router.Use(gin.Recovery())

	v1 := router.Group("/v1")
	authHandler.RegisterRoutes(v1.Group("/auth"))
	keyringHandler.RegisterRoutes(v1.Group("/keyring"))
	wsHandler.RegisterRoutes(router.Group(""))

	return router
}
