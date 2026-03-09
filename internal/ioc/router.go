package ioc

import (
	"fmt"

	"github.com/LaLanMo/muxagent-relay/internal/api"
	"github.com/LaLanMo/muxagent-relay/internal/config"
	"github.com/LaLanMo/muxagent-relay/internal/middleware"
	"github.com/gin-gonic/gin"
)

func SetupRouter(
	authHandler *api.AuthHandler,
	keyringHandler *api.KeyringHandler,
	wsHandler *api.WSHandler,
	deviceHandler *api.DeviceHandler,
	cfg *config.Config,
) (*gin.Engine, error) {
	router := gin.New()
	router.Use(gin.Recovery())

	rl := cfg.RateLimit.WithDefaults()

	// TrustedProxies: nil → trust no proxy (secure default).
	if err := router.SetTrustedProxies(rl.TrustedProxies); err != nil {
		return nil, fmt.Errorf("invalid trusted_proxies: %w", err)
	}

	authCreateRL := middleware.NewIPRateLimiter(rl.AuthCreatePerIPPerMin)
	readRL := middleware.NewIPRateLimiter(rl.ReadPerIPPerMin)
	writeRL := middleware.NewIPRateLimiter(rl.WritePerIPPerMin)
	wsUpgradeRL := middleware.NewIPRateLimiter(rl.WSUpgradePerIPPerMin)

	v1 := router.Group("/v1")

	// Auth routes
	auth := v1.Group("/auth")
	auth.POST("/request", authCreateRL.Middleware(), authHandler.AuthRequest)
	auth.GET(":id", readRL.Middleware(), authHandler.AuthStatus)
	auth.POST(":id/approve", writeRL.Middleware(), authHandler.ApproveAuth)

	// Keyring routes
	keyring := v1.Group("/keyring")
	keyring.GET(":master_id", readRL.Middleware(), keyringHandler.Get)
	keyring.GET(":master_id/updates", readRL.Middleware(), keyringHandler.ListUpdates)
	keyring.POST(":master_id/update", writeRL.Middleware(), keyringHandler.Update)

	// Device routes
	device := v1.Group("/device")
	device.PUT("/token", writeRL.Middleware(), deviceHandler.UpsertToken)
	device.DELETE("/token", writeRL.Middleware(), deviceHandler.DeleteToken)

	// WebSocket
	router.GET("/ws", wsUpgradeRL.Middleware(), wsHandler.HandleWS)

	return router, nil
}
