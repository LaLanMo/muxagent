package api

import (
	"net/http"

	"github.com/LaLanMo/muxagent-relay/internal/middleware"
	"github.com/LaLanMo/muxagent-relay/internal/service"
	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

var wsUpgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

type WSHandler struct {
	ws          service.WSService
	connLimiter *middleware.WSConnLimiter
}

func NewWSHandler(ws service.WSService, connLimiter *middleware.WSConnLimiter) *WSHandler {
	return &WSHandler{ws: ws, connLimiter: connLimiter}
}

func (h *WSHandler) RegisterRoutes(router *gin.RouterGroup) {
	router.GET("/ws", h.HandleWS)
}

func (h *WSHandler) HandleWS(c *gin.Context) {
	ip := c.ClientIP()

	if err := h.connLimiter.Acquire(ip); err != nil {
		c.JSON(http.StatusTooManyRequests, Envelope{
			Code:    CodeRateLimited,
			Message: err.Error(),
		})
		return
	}
	// CRITICAL: defer Release before Upgrade so upgrade failures also release.
	defer h.connLimiter.Release(ip)

	conn, err := wsUpgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		return // Release() via defer
	}
	conn.SetReadLimit(5 * 1024 * 1024) // 5MB for image payloads
	defer conn.Close()

	h.ws.HandleConnection(c.Request.Context(), conn)
}
