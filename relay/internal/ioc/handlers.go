package ioc

import (
	"time"

	"github.com/LaLanMo/muxagent/relay/internal/api"
	"github.com/LaLanMo/muxagent/relay/internal/config"
	"github.com/LaLanMo/muxagent/relay/internal/middleware"
	"github.com/LaLanMo/muxagent/relay/internal/repository"
	"github.com/LaLanMo/muxagent/relay/internal/service"
)

func InitAuthHandler(auth service.AuthService, cfg *config.Config) *api.AuthHandler {
	return api.NewAuthHandler(auth, cfg.Relay.PublicBaseURL)
}

func InitKeyringHandler(keyring service.KeyringService) *api.KeyringHandler {
	return api.NewKeyringHandler(keyring)
}

func InitWSHandler(ws service.WSService, connLimiter *middleware.WSConnLimiter) *api.WSHandler {
	return api.NewWSHandler(ws, connLimiter)
}

func InitDeviceHandler(tokenService service.TokenService, deviceTokens repository.DeviceTokenRepository) *api.DeviceHandler {
	return api.NewDeviceHandler(tokenService, deviceTokens)
}

func InitTokenAuthMiddleware(tokenService service.TokenService) *middleware.TokenAuthMiddleware {
	return middleware.NewTokenAuthMiddleware(tokenService)
}

func InitWSConnLimiter(cfg *config.Config) *middleware.WSConnLimiter {
	rl := cfg.RateLimit.WithDefaults()
	return middleware.NewWSConnLimiter(rl.MaxWSConnsPerIP, rl.MaxWSConnsTotal)
}

func InitWSServiceConfig(cfg *config.Config) service.WSServiceConfig {
	rl := cfg.RateLimit.WithDefaults()
	return service.WSServiceConfig{
		InboundBytesPerMin: rl.WSInboundBytesPerConnPerMin,
		RegisterTimeout:    time.Duration(rl.WSRegisterTimeoutSec) * time.Second,
	}
}
