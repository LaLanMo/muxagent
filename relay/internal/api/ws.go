package api

import (
	"log/slog"
	"net/http"
	"strings"

	"github.com/LaLanMo/muxagent/relay/internal/logging"
	"github.com/LaLanMo/muxagent/relay/internal/middleware"
	"github.com/LaLanMo/muxagent/relay/internal/service"
	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

// Relay only supports native clients. Any non-empty Origin indicates a
// browser-style request and is rejected at the upgrade boundary.
func allowWSOrigin(r *http.Request) bool {
	return strings.TrimSpace(r.Header.Get("Origin")) == ""
}

var wsUpgrader = websocket.Upgrader{
	CheckOrigin: allowWSOrigin,
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
	ctx := logging.WithClientIP(c.Request.Context(), ip)
	c.Request = c.Request.WithContext(ctx)

	if err := h.connLimiter.Acquire(ip); err != nil {
		logging.Audit(ctx, slog.LevelWarn, logging.EventWSUpgradeRejected, logging.ResultDenied, "rate limit exceeded")
		c.JSON(http.StatusTooManyRequests, Envelope{
			Code:    CodeRateLimited,
			Message: err.Error(),
		})
		return
	}
	// CRITICAL: defer Release before Upgrade so upgrade failures also release.
	defer h.connLimiter.Release(ip)

	if !allowWSOrigin(c.Request) {
		logging.Audit(ctx, slog.LevelWarn, logging.EventWSUpgradeRejected, logging.ResultDenied, "origin not allowed")
		c.Status(http.StatusForbidden)
		return
	}

	conn, err := wsUpgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		logging.Audit(ctx, slog.LevelWarn, logging.EventWSUpgradeRejected, logging.ResultError, "upgrade failed")
		return // Release() via defer
	}
	conn.SetReadLimit(5 * 1024 * 1024) // 5MB for image payloads
	defer conn.Close()

	h.ws.HandleConnection(ctx, conn)
}
