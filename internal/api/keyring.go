package api

import (
	"crypto/ed25519"
	"encoding/base64"
	"errors"
	"net/http"
	"strconv"

	"github.com/LaLanMo/muxagent-relay/internal/service"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// KeyringHandler handles keyring endpoints.
type KeyringHandler struct {
	keyringService service.KeyringService
}

// NewKeyringHandler creates a new keyring handler.
func NewKeyringHandler(keyringService service.KeyringService) *KeyringHandler {
	return &KeyringHandler{keyringService: keyringService}
}

// RegisterRoutes mounts keyring routes on the router group.
func (h *KeyringHandler) RegisterRoutes(router *gin.RouterGroup) {
	router.GET("/:master_id", h.Get)
	router.GET("/:master_id/updates", h.ListUpdates)
	router.POST("/:master_id/update", h.Update)
}

type keyringUpdateRequest struct {
	Seq                            int    `json:"seq"`
	PrevHash                       string `json:"prev_hash"`
	Action                         string `json:"action"`
	TargetMasterSignPub            string `json:"target_master_sign_pub"`
	TargetMasterEncPub             string `json:"target_master_enc_pub"`
	SignerMasterSignKeyFingerprint string `json:"signer_master_sign_key_fingerprint"`
	Signature                      string `json:"signature"`
}

type KeyringStateResponse struct {
	MasterID string                   `json:"master_id"`
	Seq      int                      `json:"seq"`
	HeadHash string                   `json:"head_hash"`
	Keys     []MasterKeyStateResponse `json:"keys"`
}

type MasterKeyStateResponse struct {
	MasterSignKeyFingerprint string `json:"master_sign_key_fingerprint"`
	MasterSignPub            string `json:"master_sign_pub"`
	MasterEncPub             string `json:"master_enc_pub"`
	RevokedAt                *int64 `json:"revoked_at,omitempty"`
}

func (h *KeyringHandler) Get(c *gin.Context) {
	masterID, err := uuid.Parse(c.Param("master_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidRequest, Message: "invalid master_id"})
		return
	}

	out, err := h.keyringService.GetKeyringState(c.Request.Context(), masterID)
	if err != nil {
		switch {
		case errors.Is(err, service.ErrMasterIdentityNotFound):
			c.JSON(http.StatusNotFound, Envelope{Code: CodeNotFound, Message: err.Error()})
		default:
			c.JSON(http.StatusInternalServerError, Envelope{Code: CodeInternalError, Message: "database error"})
		}
		return
	}
	c.JSON(http.StatusOK, Envelope{Code: CodeSuccess, Message: "success", Data: toKeyringStateResponse(out)})
}

func toKeyringStateResponse(state *service.KeyringState) KeyringStateResponse {
	out := KeyringStateResponse{
		MasterID: state.MasterID,
		Seq:      state.Seq,
		HeadHash: state.HeadHash,
		Keys:     make([]MasterKeyStateResponse, 0, len(state.Keys)),
	}
	for _, key := range state.Keys {
		var revokedAt *int64
		if key.RevokedAt != nil {
			v := key.RevokedAt.Unix()
			revokedAt = &v
		}
		out.Keys = append(out.Keys, MasterKeyStateResponse{
			MasterSignKeyFingerprint: key.MasterSignKeyFingerprint,
			MasterSignPub:            key.MasterSignPub,
			MasterEncPub:             key.MasterEncPub,
			RevokedAt:                revokedAt,
		})
	}
	return out
}

type KeyringUpdateResponse struct {
	Seq                            int    `json:"seq"`
	PrevHash                       string `json:"prev_hash"`
	UpdateHash                     string `json:"update_hash"`
	Action                         string `json:"action"`
	TargetMasterSignKeyFingerprint string `json:"target_master_sign_key_fingerprint"`
	TargetMasterSignPub            string `json:"target_master_sign_pub"`
	TargetMasterEncPub             string `json:"target_master_enc_pub,omitempty"`
	SignerMasterSignKeyFingerprint string `json:"signer_master_sign_key_fingerprint"`
	Signature                      string `json:"signature"`
	CreatedAt                      int64  `json:"created_at"`
}

type KeyringUpdatesResponse struct {
	MasterID string                  `json:"master_id"`
	FromSeq  int                     `json:"from_seq"`
	ToSeq    int                     `json:"to_seq"`
	HeadHash string                  `json:"head_hash"`
	Updates  []KeyringUpdateResponse `json:"updates"`
}

func (h *KeyringHandler) ListUpdates(c *gin.Context) {
	masterID, err := uuid.Parse(c.Param("master_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidRequest, Message: "invalid master_id"})
		return
	}

	fromSeq := 0
	if v := c.Query("from_seq"); v != "" {
		if parsed, err := strconv.Atoi(v); err == nil {
			fromSeq = parsed
		} else {
			c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidRequest, Message: "invalid from_seq"})
			return
		}
	}
	limit := 200
	if v := c.Query("limit"); v != "" {
		if parsed, err := strconv.Atoi(v); err == nil {
			limit = parsed
		} else {
			c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidRequest, Message: "invalid limit"})
			return
		}
	}

	updates, err := h.keyringService.GetKeyringUpdates(c.Request.Context(), masterID, fromSeq, limit)
	if err != nil {
		switch {
		case errors.Is(err, service.ErrMasterIdentityNotFound):
			c.JSON(http.StatusNotFound, Envelope{Code: CodeNotFound, Message: err.Error()})
		default:
			c.JSON(http.StatusInternalServerError, Envelope{Code: CodeInternalError, Message: "database error"})
		}
		return
	}

	state, err := h.keyringService.GetKeyringState(c.Request.Context(), masterID)
	if err != nil {
		switch {
		case errors.Is(err, service.ErrMasterIdentityNotFound):
			c.JSON(http.StatusNotFound, Envelope{Code: CodeNotFound, Message: err.Error()})
		default:
			c.JSON(http.StatusInternalServerError, Envelope{Code: CodeInternalError, Message: "database error"})
		}
		return
	}

	out := KeyringUpdatesResponse{
		MasterID: masterID.String(),
		FromSeq:  fromSeq,
		ToSeq:    state.Seq,
		HeadHash: state.HeadHash,
		Updates:  make([]KeyringUpdateResponse, 0, len(updates)),
	}
	for _, update := range updates {
		item := KeyringUpdateResponse{
			Seq:                            update.Seq,
			PrevHash:                       update.PrevHash,
			UpdateHash:                     update.UpdateHash,
			Action:                         update.Action,
			TargetMasterSignKeyFingerprint: update.TargetMasterSignKeyFingerprint,
			TargetMasterSignPub:            base64.StdEncoding.EncodeToString(update.TargetMasterSignPub),
			SignerMasterSignKeyFingerprint: update.SignerMasterSignKeyFingerprint,
			Signature:                      base64.StdEncoding.EncodeToString(update.Signature),
			CreatedAt:                      update.CreatedAt.Unix(),
		}
		if len(update.TargetMasterEncPub) > 0 {
			item.TargetMasterEncPub = base64.StdEncoding.EncodeToString(update.TargetMasterEncPub)
		}
		out.Updates = append(out.Updates, item)
	}

	c.JSON(http.StatusOK, Envelope{Code: CodeSuccess, Message: "success", Data: out})
}

func (h *KeyringHandler) Update(c *gin.Context) {
	masterID, err := uuid.Parse(c.Param("master_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidRequest, Message: "invalid master_id"})
		return
	}

	var input keyringUpdateRequest
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidRequest, Message: "invalid JSON"})
		return
	}

	targetSignPub, err := base64.StdEncoding.DecodeString(input.TargetMasterSignPub)
	if err != nil || len(targetSignPub) != ed25519.PublicKeySize {
		c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidPublicKey, Message: "invalid target_master_sign_pub"})
		return
	}

	var targetEncPub []byte
	if input.TargetMasterEncPub != "" {
		targetEncPub, err = base64.StdEncoding.DecodeString(input.TargetMasterEncPub)
		if err != nil || len(targetEncPub) != x25519PublicKeySize {
			c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidPublicKey, Message: "invalid target_master_enc_pub"})
			return
		}
	} else if input.Action == string(service.KeyringActionAdd) {
		c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidRequest, Message: "target_master_enc_pub required for add"})
		return
	}

	sig, err := base64.StdEncoding.DecodeString(input.Signature)
	if err != nil || len(sig) != ed25519.SignatureSize {
		c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidSignature, Message: "invalid signature"})
		return
	}

	err = h.keyringService.UpdateKeyring(c.Request.Context(), masterID, service.KeyringUpdateInput{
		MasterID:                       masterID.String(),
		Seq:                            input.Seq,
		PrevHash:                       input.PrevHash,
		Action:                         service.KeyringAction(input.Action),
		TargetMasterSignPub:            targetSignPub,
		TargetMasterEncPub:             targetEncPub,
		SignerMasterSignKeyFingerprint: input.SignerMasterSignKeyFingerprint,
		Signature:                      sig,
	})
	if err != nil {
		switch {
		case errors.Is(err, service.ErrMasterIdentityNotFound):
			c.JSON(http.StatusNotFound, Envelope{Code: CodeNotFound, Message: err.Error()})
		case errors.Is(err, service.ErrInvalidAction),
			errors.Is(err, service.ErrMasterKeyNotFoundForRevoke):
			c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidRequest, Message: err.Error()})
		case errors.Is(err, service.ErrKeyringUpdateConflict),
			errors.Is(err, service.ErrMasterKeyAlreadyExists):
			c.JSON(http.StatusConflict, Envelope{Code: CodeConflict, Message: err.Error()})
		case errors.Is(err, service.ErrSignerMasterKeyNotFound),
			errors.Is(err, service.ErrInvalidKeyringUpdateSignature):
			c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidSignature, Message: err.Error()})
		default:
			c.JSON(http.StatusInternalServerError, Envelope{Code: CodeInternalError, Message: "database error"})
		}
		return
	}
	c.JSON(http.StatusOK, Envelope{Code: CodeSuccess, Message: "success", Data: map[string]any{"status": "ok"}})
}
