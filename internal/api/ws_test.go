package api

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/LaLanMo/muxagent-relay/internal/middleware"
	"github.com/LaLanMo/muxagent-relay/internal/service"
	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type mockWSService struct {
	handleFn func(ctx context.Context, conn *websocket.Conn)
}

func (m *mockWSService) HandleConnection(ctx context.Context, conn *websocket.Conn) {
	if m.handleFn != nil {
		m.handleFn(ctx, conn)
	}
}

func newWSHandlerTestServer(t *testing.T, svc service.WSService, limiter *middleware.WSConnLimiter) *httptest.Server {
	t.Helper()
	gin.SetMode(gin.TestMode)

	if limiter == nil {
		limiter = middleware.NewWSConnLimiter(10, 10)
	}

	router := gin.New()
	handler := NewWSHandler(svc, limiter)
	router.GET("/ws", handler.HandleWS)

	srv := httptest.NewServer(router)
	t.Cleanup(srv.Close)
	return srv
}

func wsURLFromHTTP(httpURL string) string {
	return "ws" + strings.TrimPrefix(httpURL, "http") + "/ws"
}

func TestWSHandler_AllowsHandshakeWithoutOrigin(t *testing.T) {
	handled := make(chan struct{}, 1)
	srv := newWSHandlerTestServer(t, &mockWSService{
		handleFn: func(ctx context.Context, conn *websocket.Conn) {
			handled <- struct{}{}
		},
	}, nil)

	conn, _, err := websocket.DefaultDialer.Dial(wsURLFromHTTP(srv.URL), nil)
	require.NoError(t, err)
	t.Cleanup(func() { _ = conn.Close() })

	select {
	case <-handled:
	case <-time.After(time.Second):
		t.Fatal("expected websocket service to handle native handshake")
	}
}

func TestWSHandler_RejectsHandshakeWithOrigin(t *testing.T) {
	var called atomic.Bool
	srv := newWSHandlerTestServer(t, &mockWSService{
		handleFn: func(ctx context.Context, conn *websocket.Conn) {
			called.Store(true)
		},
	}, nil)

	headers := http.Header{}
	headers.Set("Origin", "https://evil.example")

	conn, resp, err := websocket.DefaultDialer.Dial(wsURLFromHTTP(srv.URL), headers)
	require.Error(t, err)
	if conn != nil {
		_ = conn.Close()
	}
	require.NotNil(t, resp)
	assert.Equal(t, http.StatusForbidden, resp.StatusCode)
	assert.False(t, called.Load())
}

func TestWSHandler_RejectedOriginDoesNotConsumeConnectionLimit(t *testing.T) {
	handled := make(chan struct{}, 1)
	limiter := middleware.NewWSConnLimiter(1, 1)
	srv := newWSHandlerTestServer(t, &mockWSService{
		handleFn: func(ctx context.Context, conn *websocket.Conn) {
			handled <- struct{}{}
		},
	}, limiter)

	headers := http.Header{}
	headers.Set("Origin", "https://evil.example")

	conn, resp, err := websocket.DefaultDialer.Dial(wsURLFromHTTP(srv.URL), headers)
	require.Error(t, err)
	if conn != nil {
		_ = conn.Close()
	}
	require.NotNil(t, resp)
	assert.Equal(t, http.StatusForbidden, resp.StatusCode)

	goodConn, _, err := websocket.DefaultDialer.Dial(wsURLFromHTTP(srv.URL), nil)
	require.NoError(t, err)
	t.Cleanup(func() { _ = goodConn.Close() })

	select {
	case <-handled:
	case <-time.After(time.Second):
		t.Fatal("expected subsequent native handshake to succeed after rejected origin")
	}
}
