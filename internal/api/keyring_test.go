package api

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"testing"

	"github.com/LaLanMo/muxagent-relay/internal/domain"
	"github.com/LaLanMo/muxagent-relay/internal/service"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type mockKeyringService struct {
	getFn     func(ctx context.Context, masterID uuid.UUID) (*service.KeyringState, error)
	updateFn  func(ctx context.Context, masterID uuid.UUID, input service.KeyringUpdateInput) error
	updatesFn func(ctx context.Context, masterID uuid.UUID, fromSeq int, limit int) ([]domain.KeyringUpdate, error)
}

func (m *mockKeyringService) GetKeyringState(ctx context.Context, masterID uuid.UUID) (*service.KeyringState, error) {
	if m.getFn != nil {
		return m.getFn(ctx, masterID)
	}
	return nil, nil
}

func (m *mockKeyringService) UpdateKeyring(ctx context.Context, masterID uuid.UUID, input service.KeyringUpdateInput) error {
	if m.updateFn != nil {
		return m.updateFn(ctx, masterID, input)
	}
	return nil
}

func (m *mockKeyringService) GetKeyringUpdates(ctx context.Context, masterID uuid.UUID, fromSeq int, limit int) ([]domain.KeyringUpdate, error) {
	if m.updatesFn != nil {
		return m.updatesFn(ctx, masterID, fromSeq, limit)
	}
	return nil, nil
}

func TestKeyringHandler_HandleUpdate_Validation(t *testing.T) {
	tests := []struct {
		name          string
		path          string
		body          interface{}
		expectStatus  int
		expectCode    int
		expectMessage string
	}{
		{
			name:          "invalid master id",
			path:          "/v1/keyring/not-a-uuid/update",
			body:          map[string]any{},
			expectStatus:  http.StatusBadRequest,
			expectCode:    CodeInvalidRequest,
			expectMessage: "invalid master_id",
		},
		{
			name:          "invalid json",
			path:          "/v1/keyring/" + uuid.NewString() + "/update",
			expectStatus:  http.StatusBadRequest,
			expectCode:    CodeInvalidRequest,
			expectMessage: "invalid JSON",
		},
		{
			name: "invalid target sign pub",
			path: "/v1/keyring/" + uuid.NewString() + "/update",
			body: map[string]any{
				"target_master_sign_pub": "bad",
			},
			expectStatus:  http.StatusBadRequest,
			expectCode:    CodeInvalidPublicKey,
			expectMessage: "invalid target_master_sign_pub",
		},
		{
			name: "missing target enc pub for add",
			path: "/v1/keyring/" + uuid.NewString() + "/update",
			body: map[string]any{
				"action":                 "add",
				"target_master_sign_pub": base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{1}, 32)),
				"target_master_enc_pub":  "",
			},
			expectStatus:  http.StatusBadRequest,
			expectCode:    CodeInvalidRequest,
			expectMessage: "target_master_enc_pub required for add",
		},
		{
			name: "invalid signature",
			path: "/v1/keyring/" + uuid.NewString() + "/update",
			body: map[string]any{
				"target_master_sign_pub": base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{1}, 32)),
				"target_master_enc_pub":  base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{2}, 32)),
				"signature":              "bad",
			},
			expectStatus:  http.StatusBadRequest,
			expectCode:    CodeInvalidSignature,
			expectMessage: "invalid signature",
		},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			handler := NewKeyringHandler(&mockKeyringService{})
			router := ginTestKeyringRouter(handler)

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

func TestKeyringHandler_HandleGet(t *testing.T) {
	tests := []struct {
		name          string
		path          string
		resp          *service.KeyringState
		err           error
		expectStatus  int
		expectCode    int
		expectMessage string
	}{
		{
			name:          "invalid master id",
			path:          "/v1/keyring/not-a-uuid",
			expectStatus:  http.StatusBadRequest,
			expectCode:    CodeInvalidRequest,
			expectMessage: "invalid master_id",
		},
		{
			name:          "not found",
			path:          "/v1/keyring/" + uuid.NewString(),
			err:           service.ErrMasterIdentityNotFound,
			expectStatus:  http.StatusNotFound,
			expectCode:    CodeNotFound,
			expectMessage: "master identity not found",
		},
		{
			name:         "success",
			path:         "/v1/keyring/" + uuid.NewString(),
			resp:         &service.KeyringState{MasterID: uuid.NewString()},
			expectStatus: http.StatusOK,
			expectCode:   CodeSuccess,
		},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			handler := NewKeyringHandler(&mockKeyringService{
				getFn: func(ctx context.Context, masterID uuid.UUID) (*service.KeyringState, error) {
					return tt.resp, tt.err
				},
			})
			router := ginTestKeyringRouter(handler)

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

func ginTestKeyringRouter(handler *KeyringHandler) *gin.Engine {
	router := gin.New()
	v1 := router.Group("/v1")
	handler.RegisterRoutes(v1.Group("/keyring"))
	return router
}
