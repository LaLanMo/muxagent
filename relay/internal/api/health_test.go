package api

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestHealthHandler_Healthy(t *testing.T) {
	gin.SetMode(gin.TestMode)

	var sawDeadline bool
	handler := NewHealthHandler(func(ctx context.Context) error {
		_, sawDeadline = ctx.Deadline()
		return nil
	})

	router := gin.New()
	router.GET("/health", handler.Handle)

	resp := performRequest(router, http.MethodGet, "/health", nil)
	require.Equal(t, http.StatusOK, resp.Code)

	var out HealthResponse
	require.NoError(t, json.NewDecoder(resp.Body).Decode(&out))
	assert.Equal(t, "ok", out.Status)
	assert.True(t, sawDeadline)
}

func TestHealthHandler_Unhealthy(t *testing.T) {
	gin.SetMode(gin.TestMode)

	handler := NewHealthHandler(func(ctx context.Context) error {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(10 * time.Millisecond):
			return errors.New("db unavailable")
		}
	})

	router := gin.New()
	router.GET("/health", handler.Handle)

	resp := performRequest(router, http.MethodGet, "/health", nil)
	require.Equal(t, http.StatusServiceUnavailable, resp.Code)

	var out HealthResponse
	require.NoError(t, json.NewDecoder(resp.Body).Decode(&out))
	assert.Equal(t, "unavailable", out.Status)
}
