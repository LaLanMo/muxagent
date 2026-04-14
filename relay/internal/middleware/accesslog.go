package middleware

import (
	"log/slog"
	"strings"
	"time"

	"github.com/LaLanMo/muxagent-relay/internal/logging"
	"github.com/gin-gonic/gin"
)

func AccessLog() gin.HandlerFunc {
	return func(c *gin.Context) {
		clientIP := c.ClientIP()
		c.Request = c.Request.WithContext(logging.WithClientIP(c.Request.Context(), clientIP))

		start := time.Now()
		c.Next()

		attrs := make([]slog.Attr, 0, 2)
		if masterID := c.Param("master_id"); masterID != "" {
			attrs = append(attrs, slog.String("master_id", masterID))
		}
		if authRequestID := authRequestIDFromContext(c); authRequestID != "" {
			attrs = append(attrs, slog.String("auth_request_id", authRequestID))
		}

		logging.HTTPAccess(
			c.Request.Context(),
			c.Request.Method,
			c.Request.URL.Path,
			c.Writer.Status(),
			time.Since(start),
			attrs...,
		)
	}
}

func authRequestIDFromContext(c *gin.Context) string {
	fullPath := c.FullPath()
	if !strings.HasPrefix(fullPath, "/v1/auth/:id") {
		return ""
	}
	return c.Param("id")
}
