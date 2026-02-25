package ioc

import (
	"github.com/LaLanMo/muxagent-relay/internal/api"
	"github.com/gin-gonic/gin"
)

func SetupRouter(authHandler *api.AuthHandler, keyringHandler *api.KeyringHandler, wsHandler *api.WSHandler) *gin.Engine {
	router := gin.New()
	router.Use(gin.Recovery())

	v1 := router.Group("/v1")
	authHandler.RegisterRoutes(v1.Group("/auth"))
	keyringHandler.RegisterRoutes(v1.Group("/keyring"))

	wsHandler.RegisterRoutes(router.Group(""))

	return router
}
