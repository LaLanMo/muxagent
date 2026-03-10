package api

import (
	"net/http"

	"github.com/LaLanMo/muxagent-relay/internal/domain"
	"github.com/LaLanMo/muxagent-relay/internal/repository"
	"github.com/LaLanMo/muxagent-relay/internal/service"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type DeviceHandler struct {
	tokenService service.TokenService
	deviceTokens repository.DeviceTokenRepository
}

func NewDeviceHandler(tokenService service.TokenService, deviceTokens repository.DeviceTokenRepository) *DeviceHandler {
	return &DeviceHandler{
		tokenService: tokenService,
		deviceTokens: deviceTokens,
	}
}

func (h *DeviceHandler) RegisterRoutes(router *gin.RouterGroup) {
	router.PUT("/token", h.UpsertToken)
	router.DELETE("/token", h.DeleteToken)
}

type upsertTokenInput struct {
	ConnectToken string `json:"connect_token"`
	FCMToken     string `json:"fcm_token"`
	Platform     string `json:"platform"`
}

func (h *DeviceHandler) UpsertToken(c *gin.Context) {
	var input upsertTokenInput
	if err := c.ShouldBindJSON(&input); err != nil {
		writeJSONDecodeError(c, err)
		return
	}
	if input.ConnectToken == "" || input.FCMToken == "" || input.Platform == "" {
		c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidRequest, Message: "connect_token, fcm_token, and platform are required"})
		return
	}

	claims, err := h.tokenService.VerifyConnectToken(c.Request.Context(), input.ConnectToken)
	if err != nil {
		c.JSON(http.StatusUnauthorized, Envelope{Code: CodeInvalidRequest, Message: "invalid connect_token"})
		return
	}

	token := &domain.DeviceToken{
		ID:       uuid.New(),
		MasterID: claims.MasterID,
		Token:    input.FCMToken,
		Platform: input.Platform,
	}
	if err := h.deviceTokens.Upsert(c.Request.Context(), token); err != nil {
		c.JSON(http.StatusInternalServerError, Envelope{Code: CodeInternalError, Message: "failed to save device token"})
		return
	}

	c.JSON(http.StatusOK, Envelope{Code: CodeSuccess, Message: "success"})
}

type deleteTokenInput struct {
	ConnectToken string `json:"connect_token"`
	FCMToken     string `json:"fcm_token"`
}

func (h *DeviceHandler) DeleteToken(c *gin.Context) {
	var input deleteTokenInput
	if err := c.ShouldBindJSON(&input); err != nil {
		writeJSONDecodeError(c, err)
		return
	}
	if input.ConnectToken == "" || input.FCMToken == "" {
		c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidRequest, Message: "connect_token and fcm_token are required"})
		return
	}

	claims, err := h.tokenService.VerifyConnectToken(c.Request.Context(), input.ConnectToken)
	if err != nil {
		c.JSON(http.StatusUnauthorized, Envelope{Code: CodeInvalidRequest, Message: "invalid connect_token"})
		return
	}

	if err := h.deviceTokens.DeleteByMasterAndToken(c.Request.Context(), claims.MasterID, input.FCMToken); err != nil {
		c.JSON(http.StatusInternalServerError, Envelope{Code: CodeInternalError, Message: "failed to delete device token"})
		return
	}

	c.JSON(http.StatusOK, Envelope{Code: CodeSuccess, Message: "success"})
}
