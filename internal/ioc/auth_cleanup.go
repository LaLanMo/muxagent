package ioc

import "github.com/LaLanMo/muxagent-relay/internal/service"

func InitAuthCleanup(auth service.AuthService) func() {
	return auth.StartCleanup()
}
