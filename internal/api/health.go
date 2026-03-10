package api

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

const healthCheckTimeout = 2 * time.Second

type HealthHandler struct {
	ping func(context.Context) error
}

type HealthResponse struct {
	Status string `json:"status"`
}

func NewHealthHandler(ping func(context.Context) error) *HealthHandler {
	return &HealthHandler{ping: ping}
}

func (h *HealthHandler) Handle(c *gin.Context) {
	if h.ping != nil {
		ctx, cancel := context.WithTimeout(c.Request.Context(), healthCheckTimeout)
		defer cancel()

		if err := h.ping(ctx); err != nil {
			c.JSON(http.StatusServiceUnavailable, HealthResponse{Status: "unavailable"})
			return
		}
	}

	c.JSON(http.StatusOK, HealthResponse{Status: "ok"})
}
