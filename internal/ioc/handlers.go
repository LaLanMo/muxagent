package ioc

import (
	"github.com/LaLanMo/muxagent-relay/internal/api"
	"github.com/LaLanMo/muxagent-relay/internal/config"
	"github.com/LaLanMo/muxagent-relay/internal/service"
)

func InitAuthHandler(auth service.AuthService, cfg *config.Config) *api.AuthHandler {
	return api.NewAuthHandler(auth, cfg.Relay.PublicBaseURL)
}

func InitKeyringHandler(keyring service.KeyringService) *api.KeyringHandler {
	return api.NewKeyringHandler(keyring)
}

func InitWSHandler(ws service.WSService) *api.WSHandler {
	return api.NewWSHandler(ws)
}
