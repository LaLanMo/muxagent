package intergration

import (
	"crypto/ed25519"

	"github.com/LaLanMo/muxagent-relay/internal/service"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type testContainer struct {
	Router         *gin.Engine
	DB             *gorm.DB
	AuthService    service.AuthService
	KeyringService service.KeyringService
	RelayPriv      ed25519.PrivateKey
	RelayPub       ed25519.PublicKey
	Cleanup        func()
}
