package api

import (
	"net/http"

	"github.com/LaLanMo/muxagent-relay/internal/service"
	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

var wsUpgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

type WSHandler struct {
	ws service.WSService
}

func NewWSHandler(ws service.WSService) *WSHandler {
	return &WSHandler{ws: ws}
}

func (h *WSHandler) RegisterRoutes(router *gin.RouterGroup) {
	router.GET("/ws", h.HandleWS)
}

func (h *WSHandler) HandleWS(c *gin.Context) {
	conn, err := wsUpgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		return
	}
	defer conn.Close()
	h.ws.HandleConnection(c.Request.Context(), conn)
}
