package api

import (
	"crypto/ed25519"
	"encoding/base64"
	"errors"
	"net/http"
	"net/url"
	"strings"

	"github.com/LaLanMo/muxagent-relay/internal/service"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// AuthHandler handles device pairing requests.
type AuthHandler struct {
	authService service.AuthService
	relayURL    string
}

// NewAuthHandler creates a new auth handler.
func NewAuthHandler(authService service.AuthService, relayURL string) *AuthHandler {
	return &AuthHandler{
		authService: authService,
		relayURL:    relayURL,
	}
}

// RegisterRoutes mounts auth routes on the router group.
func (h *AuthHandler) RegisterRoutes(router *gin.RouterGroup) {
	router.POST("/request", h.AuthRequest)
	router.GET("/:id", h.AuthStatus)
	router.POST("/:id/approve", h.ApproveAuth)
}

type authRequestInput struct {
	MachineID      string `json:"machine_id"`
	MachineSignPub string `json:"machine_sign_pub"`
	MachineEncPub  string `json:"machine_enc_pub"`
	Hostname       string `json:"hostname,omitempty"`
}

func (h *AuthHandler) AuthRequest(c *gin.Context) {
	var input authRequestInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidRequest, Message: "invalid JSON"})
		return
	}

	machineID, err := uuid.Parse(input.MachineID)
	if err != nil {
		c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidRequest, Message: "invalid machine_id"})
		return
	}

	machineSignPub, err := base64.StdEncoding.DecodeString(input.MachineSignPub)
	if err != nil || len(machineSignPub) != ed25519.PublicKeySize {
		c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidPublicKey, Message: "invalid machine_sign_pub"})
		return
	}

	machineEncPub, err := base64.StdEncoding.DecodeString(input.MachineEncPub)
	if err != nil || len(machineEncPub) != x25519PublicKeySize {
		c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidPublicKey, Message: "invalid machine_enc_pub"})
		return
	}

	req, err := h.authService.CreateAuthRequest(c.Request.Context(), machineID, machineSignPub, machineEncPub, input.Hostname)
	if err != nil {
		c.JSON(http.StatusInternalServerError, Envelope{Code: CodeInternalError, Message: "failed to create auth request"})
		return
	}

	output := service.AuthRequestResult{
		RequestID: req.ID.String(),
		QRURL:     buildQRURL(req.ID.String(), h.relayURL),
		ExpiresAt: req.ExpiresAt,
		PollToken: base64.RawURLEncoding.EncodeToString(req.PollToken),
	}
	c.JSON(http.StatusCreated, Envelope{Code: CodeSuccess, Message: "success", Data: toAuthRequestResponse(output)})
}

func (h *AuthHandler) AuthStatus(c *gin.Context) {
	reqID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidRequest, Message: "invalid auth request id"})
		return
	}

	var pollToken []byte
	if authHeader := c.GetHeader("Authorization"); authHeader != "" {
		if token, ok := strings.CutPrefix(authHeader, "Bearer "); ok {
			if decoded, err := base64.RawURLEncoding.DecodeString(token); err == nil {
				pollToken = decoded
			}
		}
	}

	status, err := h.authService.GetAuthStatus(c.Request.Context(), reqID, pollToken)
	if err != nil {
		switch {
		case errors.Is(err, service.ErrAuthRequestNotFound):
			c.JSON(http.StatusNotFound, Envelope{Code: CodeNotFound, Message: err.Error()})
		default:
			c.JSON(http.StatusInternalServerError, Envelope{Code: CodeInternalError, Message: "database error"})
		}
		return
	}
	c.JSON(http.StatusOK, Envelope{Code: CodeSuccess, Message: "success", Data: toAuthStatusResponse(status)})
}

type keyringUpdateInput struct {
	MasterID                       string `json:"master_id"`
	Seq                            int    `json:"seq"`
	PrevHash                       string `json:"prev_hash"`
	Action                         string `json:"action"`
	TargetMasterSignPub            string `json:"target_master_sign_pub"`
	TargetMasterEncPub             string `json:"target_master_enc_pub"`
	SignerMasterSignKeyFingerprint string `json:"signer_master_sign_key_fingerprint"`
	Signature                      string `json:"signature"`
}

type authApproveInput struct {
	MasterID          string              `json:"master_id"`
	MasterSignPub     string              `json:"master_sign_pub"`
	MasterEncPub      string              `json:"master_enc_pub"`
	ApprovalSignature string              `json:"approval_signature"`
	KeyringUpdate     *keyringUpdateInput `json:"keyring_update,omitempty"`
}

type AuthRequestResponse struct {
	RequestID string `json:"request_id"`
	QRURL     string `json:"qr_url"`
	ExpiresAt int64  `json:"expires_at"`
	PollToken string `json:"poll_token"`
}

type AuthStatusResponse struct {
	State                              service.AuthStatusState `json:"state"`
	RequestID                          string                  `json:"request_id"`
	MachineID                          string                  `json:"machine_id"`
	MachineSignPub                     string                  `json:"machine_sign_pub"`
	MachineEncPub                      string                  `json:"machine_enc_pub"`
	MachineHostname                    string                  `json:"machine_hostname,omitempty"`
	RelayChallenge                     string                  `json:"relay_challenge"`
	ExpiresAt                          int64                   `json:"expires_at"`
	ApprovedAt                         *int64                  `json:"approved_at,omitempty"`
	ApprovedByMasterSignKeyFingerprint string                  `json:"approved_by_master_sign_key_fingerprint,omitempty"`
	ApprovalSignature                  string                  `json:"approval_signature,omitempty"`
	MasterID                           string                  `json:"master_id,omitempty"`
	Keyring                            *KeyringStateResponse   `json:"keyring,omitempty"`
	RelayPubKey                        string                  `json:"relay_pub_key,omitempty"`
	RelaySignature                     string                  `json:"relay_signature,omitempty"`
}

func toAuthRequestResponse(out service.AuthRequestResult) AuthRequestResponse {
	return AuthRequestResponse{
		RequestID: out.RequestID,
		QRURL:     out.QRURL,
		ExpiresAt: out.ExpiresAt.Unix(),
		PollToken: out.PollToken,
	}
}

func toAuthStatusResponse(status *service.AuthStatus) AuthStatusResponse {
	var approvedAt *int64
	if status.ApprovedAt != nil {
		v := status.ApprovedAt.Unix()
		approvedAt = &v
	}
	var keyring *KeyringStateResponse
	if status.Keyring != nil {
		kr := toKeyringStateResponse(status.Keyring)
		keyring = &kr
	}
	return AuthStatusResponse{
		State:                              status.State,
		RequestID:                          status.RequestID,
		MachineID:                          status.MachineID,
		MachineSignPub:                     status.MachineSignPub,
		MachineEncPub:                      status.MachineEncPub,
		MachineHostname:                    status.MachineHostname,
		RelayChallenge:                     status.RelayChallenge,
		ExpiresAt:                          status.ExpiresAt.Unix(),
		ApprovedAt:                         approvedAt,
		ApprovedByMasterSignKeyFingerprint: status.ApprovedByMasterSignKeyFingerprint,
		ApprovalSignature:                  status.ApprovalSignature,
		MasterID:                           status.MasterID,
		Keyring:                            keyring,
		RelayPubKey:                        status.RelayPubKey,
		RelaySignature:                     status.RelaySignature,
	}
}

func (h *AuthHandler) ApproveAuth(c *gin.Context) {
	reqID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidRequest, Message: "invalid auth request id"})
		return
	}

	var input authApproveInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidRequest, Message: "invalid JSON"})
		return
	}

	masterSignPub, err := base64.StdEncoding.DecodeString(input.MasterSignPub)
	if err != nil || len(masterSignPub) != ed25519.PublicKeySize {
		c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidPublicKey, Message: "invalid master_sign_pub"})
		return
	}
	masterEncPub, err := base64.StdEncoding.DecodeString(input.MasterEncPub)
	if err != nil || len(masterEncPub) != x25519PublicKeySize {
		c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidPublicKey, Message: "invalid master_enc_pub"})
		return
	}
	approvalSig, err := base64.StdEncoding.DecodeString(input.ApprovalSignature)
	if err != nil || len(approvalSig) != ed25519.SignatureSize {
		c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidSignature, Message: "invalid approval_signature"})
		return
	}

	var keyringUpdate *service.KeyringUpdateInput
	if input.KeyringUpdate != nil {
		targetSignPub, err := base64.StdEncoding.DecodeString(input.KeyringUpdate.TargetMasterSignPub)
		if err != nil || len(targetSignPub) != ed25519.PublicKeySize {
			c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidPublicKey, Message: "invalid keyring_update target master_sign_pub"})
			return
		}
		var targetEncPub []byte
		if input.KeyringUpdate.TargetMasterEncPub != "" {
			targetEncPub, err = base64.StdEncoding.DecodeString(input.KeyringUpdate.TargetMasterEncPub)
			if err != nil || len(targetEncPub) != x25519PublicKeySize {
				c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidPublicKey, Message: "invalid keyring_update target master_enc_pub"})
				return
			}
		} else if input.KeyringUpdate.Action == string(service.KeyringActionAdd) {
			c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidRequest, Message: "keyring_update target master_enc_pub required for add"})
			return
		}
		sig, err := base64.StdEncoding.DecodeString(input.KeyringUpdate.Signature)
		if err != nil || len(sig) != ed25519.SignatureSize {
			c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidSignature, Message: "invalid keyring update signature"})
			return
		}
		keyringUpdate = &service.KeyringUpdateInput{
			MasterID:                       input.KeyringUpdate.MasterID,
			Seq:                            input.KeyringUpdate.Seq,
			PrevHash:                       input.KeyringUpdate.PrevHash,
			Action:                         service.KeyringAction(input.KeyringUpdate.Action),
			TargetMasterSignPub:            targetSignPub,
			TargetMasterEncPub:             targetEncPub,
			SignerMasterSignKeyFingerprint: input.KeyringUpdate.SignerMasterSignKeyFingerprint,
			Signature:                      sig,
		}
	}

	status, err := h.authService.ApproveAuthRequest(c.Request.Context(), reqID, service.AuthApproveInput{
		MasterID:          input.MasterID,
		MasterSignPub:     masterSignPub,
		MasterEncPub:      masterEncPub,
		ApprovalSignature: approvalSig,
		KeyringUpdate:     keyringUpdate,
	})
	if err != nil {
		switch {
		case errors.Is(err, service.ErrAuthRequestNotFound):
			c.JSON(http.StatusNotFound, Envelope{Code: CodeNotFound, Message: err.Error()})
		case errors.Is(err, service.ErrAuthRequestExpired):
			c.JSON(http.StatusGone, Envelope{Code: CodeExpired, Message: err.Error()})
		case errors.Is(err, service.ErrInvalidMasterApprovalSignature),
			errors.Is(err, service.ErrInvalidKeyringUpdateSignature),
			errors.Is(err, service.ErrKeyringUpdateMasterIDMissing),
			errors.Is(err, service.ErrKeyringUpdateMasterIDMismatch),
			errors.Is(err, service.ErrKeyringUpdateSeqInvalid),
			errors.Is(err, service.ErrKeyringUpdatePrevHashInvalid),
			errors.Is(err, service.ErrKeyringUpdateActionInvalid),
			errors.Is(err, service.ErrKeyringUpdateTargetMasterSignMismatch),
			errors.Is(err, service.ErrKeyringUpdateTargetMasterEncMismatch),
			errors.Is(err, service.ErrKeyringUpdateSignerFingerprintMismatch):
			c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidSignature, Message: err.Error()})
		case errors.Is(err, service.ErrMasterKeyRevoked):
			c.JSON(http.StatusForbidden, Envelope{Code: CodeRevoked, Message: err.Error()})
		case errors.Is(err, service.ErrMasterEncPubMismatch),
			errors.Is(err, service.ErrMasterIDMismatch),
			errors.Is(err, service.ErrKeyringUpdateRequired),
			errors.Is(err, service.ErrInvalidMasterID),
			errors.Is(err, service.ErrMachineRevoked):
			c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidRequest, Message: err.Error()})
		case errors.Is(err, service.ErrMasterIdentityExists),
			errors.Is(err, service.ErrMachineAlreadyBound):
			c.JSON(http.StatusConflict, Envelope{Code: CodeConflict, Message: err.Error()})
		default:
			c.JSON(http.StatusInternalServerError, Envelope{Code: CodeInternalError, Message: "database error"})
		}
		return
	}
	c.JSON(http.StatusOK, Envelope{Code: CodeSuccess, Message: "success", Data: toAuthStatusResponse(status)})
}

func buildQRURL(requestID, relayURL string) string {
	return "muxagent://auth?id=" + url.QueryEscape(requestID) + "&relay=" + url.QueryEscape(relayURL)
}
