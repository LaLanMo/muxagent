package middleware

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/LaLanMo/muxagent-relay/internal/logging"
	"github.com/LaLanMo/muxagent-relay/internal/service"
	"github.com/LaLanMo/muxagent-relay/internal/testutil"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type accessLogTokenServiceStub struct {
	verifyConnectFn       func(ctx context.Context, token string) (service.ConnectTokenClaims, error)
	verifyMachineFn       func(ctx context.Context, token string) (service.MachineTokenClaims, error)
	verifyMachineAccessFn func(ctx context.Context, token string) (service.MachineAccessTokenClaims, error)
}

func (s *accessLogTokenServiceStub) VerifyConnectToken(ctx context.Context, token string) (service.ConnectTokenClaims, error) {
	if s.verifyConnectFn != nil {
		return s.verifyConnectFn(ctx, token)
	}
	return service.ConnectTokenClaims{}, service.ErrInvalidConnectToken
}

func (s *accessLogTokenServiceStub) VerifyMachineToken(ctx context.Context, token string) (service.MachineTokenClaims, error) {
	if s.verifyMachineFn != nil {
		return s.verifyMachineFn(ctx, token)
	}
	return service.MachineTokenClaims{}, service.ErrInvalidMachineToken
}

func (s *accessLogTokenServiceStub) VerifyMachineAccessToken(ctx context.Context, token string) (service.MachineAccessTokenClaims, error) {
	if s.verifyMachineAccessFn != nil {
		return s.verifyMachineAccessFn(ctx, token)
	}
	return service.MachineAccessTokenClaims{}, service.ErrInvalidMachineAccessToken
}

func TestAccessLog_LogsSuccessfulRequest(t *testing.T) {
	buf := testutil.CaptureSlog(t)

	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(AccessLog())
	router.GET("/v1/auth/:id", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})

	req := httptest.NewRequest(http.MethodGet, "/v1/auth/req-123", nil)
	req.Header.Set("Authorization", "Bearer secret-poll-token")
	req.RemoteAddr = "198.51.100.10:1234"
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	require.Equal(t, http.StatusOK, rec.Code)

	entries := testutil.ParseLogEntries(t, buf)
	accessEntries := testutil.FindEntriesByEvent(entries, logging.EventHTTPAccess)
	require.Len(t, accessEntries, 1)

	entry := accessEntries[0]
	assert.Equal(t, logging.ResultSuccess, entry["result"])
	assert.Equal(t, http.MethodGet, entry["method"])
	assert.Equal(t, "/v1/auth/req-123", entry["path"])
	assert.Equal(t, float64(http.StatusOK), entry["status"])
	assert.Equal(t, "198.51.100.10", entry["client_ip"])
	assert.Equal(t, "req-123", entry["auth_request_id"])
	assert.Contains(t, entry, "latency_ms")
	assert.NotContains(t, buf.String(), "secret-poll-token")
}

func TestAccessLog_LogsUnauthorizedRequest(t *testing.T) {
	buf := testutil.CaptureSlog(t)

	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(AccessLog())

	masterID := uuid.New()
	tokenAuth := NewTokenAuthMiddleware(&accessLogTokenServiceStub{})
	router.GET("/v1/keyring/:master_id", tokenAuth.RequireMasterAccess(), func(c *gin.Context) {
		c.Status(http.StatusNoContent)
	})

	req := httptest.NewRequest(http.MethodGet, "/v1/keyring/"+masterID.String(), nil)
	req.RemoteAddr = "203.0.113.5:4567"
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	require.Equal(t, http.StatusUnauthorized, rec.Code)

	entries := testutil.ParseLogEntries(t, buf)
	accessEntries := testutil.FindEntriesByEvent(entries, logging.EventHTTPAccess)
	require.Len(t, accessEntries, 1)

	entry := accessEntries[0]
	assert.Equal(t, logging.ResultDenied, entry["result"])
	assert.Equal(t, float64(http.StatusUnauthorized), entry["status"])
	assert.Equal(t, "203.0.113.5", entry["client_ip"])
	assert.Equal(t, masterID.String(), entry["master_id"])
	assert.NotContains(t, buf.String(), "Authorization")
}

func TestAccessLog_LogsRateLimitedRequest(t *testing.T) {
	buf := testutil.CaptureSlog(t)

	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(AccessLog())

	rl := NewIPRateLimiter(1)
	t.Cleanup(rl.Stop)
	router.GET("/limited", rl.Middleware(), func(c *gin.Context) {
		c.Status(http.StatusOK)
	})

	firstReq := httptest.NewRequest(http.MethodGet, "/limited", nil)
	firstReq.RemoteAddr = "192.0.2.44:7890"
	firstRec := httptest.NewRecorder()
	router.ServeHTTP(firstRec, firstReq)
	require.Equal(t, http.StatusOK, firstRec.Code)

	secondReq := httptest.NewRequest(http.MethodGet, "/limited", nil)
	secondReq.RemoteAddr = "192.0.2.44:7890"
	secondRec := httptest.NewRecorder()
	router.ServeHTTP(secondRec, secondReq)
	require.Equal(t, http.StatusTooManyRequests, secondRec.Code)

	entries := testutil.ParseLogEntries(t, buf)
	accessEntries := testutil.FindEntriesByEvent(entries, logging.EventHTTPAccess)

	var rateLimitedEntry map[string]any
	for _, entry := range accessEntries {
		if entry["status"] == float64(http.StatusTooManyRequests) {
			rateLimitedEntry = entry
			break
		}
	}

	require.NotNil(t, rateLimitedEntry)
	assert.Equal(t, logging.ResultDenied, rateLimitedEntry["result"])
	assert.Equal(t, "/limited", rateLimitedEntry["path"])
	assert.Equal(t, "192.0.2.44", rateLimitedEntry["client_ip"])
}
