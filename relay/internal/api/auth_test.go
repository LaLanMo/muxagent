package api

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/LaLanMo/muxagent/relay/internal/domain"
	"github.com/LaLanMo/muxagent/relay/internal/service"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type mockAuthService struct {
	createFn      func(ctx context.Context, machineID uuid.UUID, machineSignPub, machineEncPub []byte) (*domain.AuthRequest, error)
	statusFn      func(ctx context.Context, requestID uuid.UUID) (*service.AuthStatus, error)
	approveFn     func(ctx context.Context, requestID uuid.UUID, input service.AuthApproveInput) (*service.AuthStatus, error)
	lastPollToken []byte
}

func (m *mockAuthService) CreateAuthRequest(ctx context.Context, machineID uuid.UUID, machineSignPub, machineEncPub []byte, hostname string) (*domain.AuthRequest, error) {
	if m.createFn != nil {
		return m.createFn(ctx, machineID, machineSignPub, machineEncPub)
	}
	return nil, nil
}

func (m *mockAuthService) GetAuthStatus(ctx context.Context, requestID uuid.UUID, pollToken []byte) (*service.AuthStatus, error) {
	m.lastPollToken = pollToken
	if m.statusFn != nil {
		return m.statusFn(ctx, requestID)
	}
	return nil, nil
}

func (m *mockAuthService) ApproveAuthRequest(ctx context.Context, requestID uuid.UUID, input service.AuthApproveInput) (*service.AuthStatus, error) {
	if m.approveFn != nil {
		return m.approveFn(ctx, requestID, input)
	}
	return nil, nil
}

func (m *mockAuthService) StartCleanup() func() {
	return func() {}
}

func TestAuthHandler_HandleAuthRequest(t *testing.T) {
	tests := []struct {
		name            string
		method          string
		body            interface{}
		rawBody         string
		expectStatus    int
		expectCode      int
		expectMessage   string
		mockCreateError error
	}{
		{
			name:          "invalid json",
			method:        http.MethodPost,
			rawBody:       "{invalid",
			expectStatus:  http.StatusBadRequest,
			expectCode:    CodeInvalidRequest,
			expectMessage: "invalid JSON",
		},
		{
			name:          "invalid machine id",
			method:        http.MethodPost,
			body:          map[string]string{"machine_id": "not-a-uuid"},
			expectStatus:  http.StatusBadRequest,
			expectCode:    CodeInvalidRequest,
			expectMessage: "invalid machine_id",
		},
		{
			name:          "invalid sign pub",
			method:        http.MethodPost,
			body:          map[string]string{"machine_id": uuid.NewString(), "machine_sign_pub": "bad", "machine_enc_pub": base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{1}, 32))},
			expectStatus:  http.StatusBadRequest,
			expectCode:    CodeInvalidPublicKey,
			expectMessage: "invalid machine_sign_pub",
		},
		{
			name:          "invalid enc pub",
			method:        http.MethodPost,
			body:          map[string]string{"machine_id": uuid.NewString(), "machine_sign_pub": base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{1}, 32)), "machine_enc_pub": "bad"},
			expectStatus:  http.StatusBadRequest,
			expectCode:    CodeInvalidPublicKey,
			expectMessage: "invalid machine_enc_pub",
		},
		{
			name:         "success",
			method:       http.MethodPost,
			body:         map[string]string{"machine_id": uuid.NewString(), "machine_sign_pub": base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{1}, 32)), "machine_enc_pub": base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{2}, 32))},
			expectStatus: http.StatusCreated,
			expectCode:   CodeSuccess,
		},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			mockSvc := &mockAuthService{
				createFn: func(ctx context.Context, machineID uuid.UUID, machineSignPub, machineEncPub []byte) (*domain.AuthRequest, error) {
					return &domain.AuthRequest{
						ID:        uuid.New(),
						ExpiresAt: time.Now().Add(5 * time.Minute),
					}, tt.mockCreateError
				},
			}
			handler := NewAuthHandler(mockSvc, "https://relay.test")
			router := ginTestRouter(handler)

			var body []byte
			if tt.rawBody != "" {
				body = []byte(tt.rawBody)
			} else if tt.body != nil {
				body, _ = json.Marshal(tt.body)
			}

			resp := performRequest(router, tt.method, "/v1/auth/request", body)
			require.Equal(t, tt.expectStatus, resp.Code)

			var env Envelope
			require.NoError(t, json.NewDecoder(resp.Body).Decode(&env))
			assert.Equal(t, tt.expectCode, env.Code)
			if tt.expectMessage != "" {
				assert.Equal(t, tt.expectMessage, env.Message)
			}
		})
	}
}

func TestAuthHandler_HandleAuthStatus(t *testing.T) {
	tests := []struct {
		name          string
		path          string
		statusResp    *service.AuthStatus
		statusErr     error
		expectStatus  int
		expectCode    int
		expectMessage string
	}{
		{
			name:          "invalid id",
			path:          "/v1/auth/not-a-uuid",
			expectStatus:  http.StatusBadRequest,
			expectCode:    CodeInvalidRequest,
			expectMessage: "invalid auth request id",
		},
		{
			name:          "not found",
			path:          "/v1/auth/" + uuid.NewString(),
			statusErr:     service.ErrAuthRequestNotFound,
			expectStatus:  http.StatusNotFound,
			expectCode:    CodeNotFound,
			expectMessage: "auth request not found",
		},
		{
			name: "success",
			path: "/v1/auth/" + uuid.NewString(),
			statusResp: &service.AuthStatus{
				State: service.AuthStatusPending,
			},
			expectStatus: http.StatusOK,
			expectCode:   CodeSuccess,
		},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			mockSvc := &mockAuthService{
				statusFn: func(ctx context.Context, requestID uuid.UUID) (*service.AuthStatus, error) {
					return tt.statusResp, tt.statusErr
				},
			}
			handler := NewAuthHandler(mockSvc, "https://relay.test")
			router := ginTestRouter(handler)

			resp := performRequest(router, http.MethodGet, tt.path, nil)
			require.Equal(t, tt.expectStatus, resp.Code)

			var env Envelope
			require.NoError(t, json.NewDecoder(resp.Body).Decode(&env))
			assert.Equal(t, tt.expectCode, env.Code)
			if tt.expectMessage != "" {
				assert.Equal(t, tt.expectMessage, env.Message)
			}
		})
	}
}

func TestAuthHandler_HandleAuthApprove_Validation(t *testing.T) {
	tests := []struct {
		name          string
		path          string
		body          interface{}
		expectStatus  int
		expectCode    int
		expectMessage string
	}{
		{
			name:          "invalid id",
			path:          "/v1/auth/not-a-uuid/approve",
			body:          map[string]any{},
			expectStatus:  http.StatusBadRequest,
			expectCode:    CodeInvalidRequest,
			expectMessage: "invalid auth request id",
		},
		{
			name:          "invalid json",
			path:          "/v1/auth/" + uuid.NewString() + "/approve",
			expectStatus:  http.StatusBadRequest,
			expectCode:    CodeInvalidRequest,
			expectMessage: "invalid JSON",
		},
		{
			name:          "invalid master sign pub",
			path:          "/v1/auth/" + uuid.NewString() + "/approve",
			body:          map[string]any{"master_sign_pub": "bad"},
			expectStatus:  http.StatusBadRequest,
			expectCode:    CodeInvalidPublicKey,
			expectMessage: "invalid master_sign_pub",
		},
		{
			name:          "invalid master enc pub",
			path:          "/v1/auth/" + uuid.NewString() + "/approve",
			body:          map[string]any{"master_sign_pub": base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{1}, 32)), "master_enc_pub": "bad"},
			expectStatus:  http.StatusBadRequest,
			expectCode:    CodeInvalidPublicKey,
			expectMessage: "invalid master_enc_pub",
		},
		{
			name:          "invalid approval signature",
			path:          "/v1/auth/" + uuid.NewString() + "/approve",
			body:          map[string]any{"master_sign_pub": base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{1}, 32)), "master_enc_pub": base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{2}, 32)), "approval_signature": "bad"},
			expectStatus:  http.StatusBadRequest,
			expectCode:    CodeInvalidSignature,
			expectMessage: "invalid approval_signature",
		},
		{
			name: "keyring update missing enc pub for add",
			path: "/v1/auth/" + uuid.NewString() + "/approve",
			body: map[string]any{
				"master_sign_pub":    base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{1}, 32)),
				"master_enc_pub":     base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{2}, 32)),
				"approval_signature": base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{3}, 64)),
				"keyring_update": map[string]any{
					"action":                 "add",
					"target_master_sign_pub": base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{4}, 32)),
					"target_master_enc_pub":  "",
					"signature":              base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{5}, 64)),
				},
			},
			expectStatus:  http.StatusBadRequest,
			expectCode:    CodeInvalidRequest,
			expectMessage: "keyring_update target master_enc_pub required for add",
		},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			mockSvc := &mockAuthService{}
			handler := NewAuthHandler(mockSvc, "https://relay.test")
			router := ginTestRouter(handler)

			var body []byte
			if tt.body != nil {
				body, _ = json.Marshal(tt.body)
			}

			resp := performRequest(router, http.MethodPost, tt.path, body)
			require.Equal(t, tt.expectStatus, resp.Code)

			var env Envelope
			require.NoError(t, json.NewDecoder(resp.Body).Decode(&env))
			assert.Equal(t, tt.expectCode, env.Code)
			assert.Equal(t, tt.expectMessage, env.Message)
		})
	}
}

func ginTestRouter(handler *AuthHandler) *gin.Engine {
	router := gin.New()
	v1 := router.Group("/v1")
	handler.RegisterRoutes(v1.Group("/auth"))
	return router
}

func performRequest(router http.Handler, method, path string, body []byte) *httptest.ResponseRecorder {
	req := httptest.NewRequest(method, path, bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	return rec
}

func TestAuthHandler_HandleAuthStatus_PollTokenExtraction(t *testing.T) {
	gin.SetMode(gin.TestMode)
	reqID := uuid.NewString()

	tests := []struct {
		name             string
		authHeader       string
		wantNilPollToken bool
	}{
		{"no header", "", true},
		{"not bearer prefix", "Basic abc123", true},
		{"invalid base64", "Bearer !!!invalid!!!", true},
		{"valid bearer", "Bearer " + base64.RawURLEncoding.EncodeToString([]byte("some-token")), false},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			mockSvc := &mockAuthService{
				statusFn: func(ctx context.Context, requestID uuid.UUID) (*service.AuthStatus, error) {
					return &service.AuthStatus{State: service.AuthStatusPending}, nil
				},
			}
			handler := NewAuthHandler(mockSvc, "https://relay.test")
			router := ginTestRouter(handler)

			req := httptest.NewRequest(http.MethodGet, "/v1/auth/"+reqID, nil)
			if tt.authHeader != "" {
				req.Header.Set("Authorization", tt.authHeader)
			}
			rec := httptest.NewRecorder()
			router.ServeHTTP(rec, req)
			require.Equal(t, http.StatusOK, rec.Code)

			if tt.wantNilPollToken {
				assert.Nil(t, mockSvc.lastPollToken)
			} else {
				assert.NotNil(t, mockSvc.lastPollToken)
			}
		})
	}
}
