package middleware

import (
	"encoding/base64"
	"log/slog"
	"net/http"
	"strings"

	"github.com/LaLanMo/muxagent/relay/internal/errs"
	"github.com/LaLanMo/muxagent/relay/internal/logging"
	"github.com/LaLanMo/muxagent/relay/internal/service"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// authEnvelope is a minimal response type to avoid importing api (cycle).
type authEnvelope struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

// TokenAuthMiddleware verifies bearer tokens on protected routes.
type TokenAuthMiddleware struct {
	tokenService service.TokenService
}

func NewTokenAuthMiddleware(tokenService service.TokenService) *TokenAuthMiddleware {
	return &TokenAuthMiddleware{tokenService: tokenService}
}

// RequireMasterAccess returns middleware that requires a valid connect_token or
// machine_access_token whose MasterID matches the :master_id path parameter.
func (m *TokenAuthMiddleware) RequireMasterAccess() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := logging.WithClientIP(c.Request.Context(), c.ClientIP())
		c.Request = c.Request.WithContext(ctx)

		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			logging.Audit(ctx, slog.LevelWarn, logging.EventAuthzDenied, logging.ResultDenied, "authorization required")
			c.AbortWithStatusJSON(http.StatusUnauthorized, authEnvelope{
				Code:    errs.CodeUnauthorized,
				Message: "authorization required",
			})
			return
		}

		token, ok := strings.CutPrefix(authHeader, "Bearer ")
		if !ok || token == "" {
			logging.Audit(ctx, slog.LevelWarn, logging.EventAuthzDenied, logging.ResultDenied, "invalid authorization header")
			c.AbortWithStatusJSON(http.StatusUnauthorized, authEnvelope{
				Code:    errs.CodeUnauthorized,
				Message: "invalid authorization header",
			})
			return
		}

		masterIDParam, err := uuid.Parse(c.Param("master_id"))
		if err != nil {
			c.AbortWithStatusJSON(http.StatusBadRequest, authEnvelope{
				Code:    errs.CodeInvalidRequest,
				Message: "invalid master_id",
			})
			return
		}

		// Peek at token prefix to determine type
		prefix := peekTokenPrefix(token)

		switch prefix {
		case service.TokenPrefixConnect:
			claims, err := m.tokenService.VerifyConnectToken(c.Request.Context(), token)
			if err != nil {
				if isDBError(err) {
					c.AbortWithStatusJSON(http.StatusInternalServerError, authEnvelope{
						Code:    errs.CodeInternalError,
						Message: "internal error",
					})
					return
				}
				logging.Audit(ctx, slog.LevelWarn, logging.EventAuthzDenied, logging.ResultDenied, "invalid token")
				c.AbortWithStatusJSON(http.StatusUnauthorized, authEnvelope{
					Code:    errs.CodeUnauthorized,
					Message: "invalid token",
				})
				return
			}
			if claims.MasterID != masterIDParam {
				logging.Audit(
					ctx,
					slog.LevelWarn,
					logging.EventAuthzDenied,
					logging.ResultDenied,
					"token master_id mismatch",
					slog.String("master_id", masterIDParam.String()),
				)
				c.AbortWithStatusJSON(http.StatusForbidden, authEnvelope{
					Code:    errs.CodeUnauthorized,
					Message: "token master_id mismatch",
				})
				return
			}

		case service.TokenPrefixMachineAccess:
			claims, err := m.tokenService.VerifyMachineAccessToken(c.Request.Context(), token)
			if err != nil {
				if isDBError(err) {
					c.AbortWithStatusJSON(http.StatusInternalServerError, authEnvelope{
						Code:    errs.CodeInternalError,
						Message: "internal error",
					})
					return
				}
				logging.Audit(ctx, slog.LevelWarn, logging.EventAuthzDenied, logging.ResultDenied, "invalid token")
				c.AbortWithStatusJSON(http.StatusUnauthorized, authEnvelope{
					Code:    errs.CodeUnauthorized,
					Message: "invalid token",
				})
				return
			}
			if claims.MasterID != masterIDParam {
				logging.Audit(
					ctx,
					slog.LevelWarn,
					logging.EventAuthzDenied,
					logging.ResultDenied,
					"token master_id mismatch",
					slog.String("master_id", masterIDParam.String()),
				)
				c.AbortWithStatusJSON(http.StatusForbidden, authEnvelope{
					Code:    errs.CodeUnauthorized,
					Message: "token master_id mismatch",
				})
				return
			}

		default:
			logging.Audit(ctx, slog.LevelWarn, logging.EventAuthzDenied, logging.ResultDenied, "invalid token")
			c.AbortWithStatusJSON(http.StatusUnauthorized, authEnvelope{
				Code:    errs.CodeUnauthorized,
				Message: "invalid token",
			})
			return
		}

		c.Next()
	}
}

// peekTokenPrefix decodes the base64 payload portion of the token and returns
// the first segment before "|". Returns empty string if decoding fails.
func peekTokenPrefix(token string) string {
	dotIdx := strings.IndexByte(token, '.')
	if dotIdx < 0 {
		return ""
	}
	payloadBytes, err := base64.RawURLEncoding.DecodeString(token[:dotIdx])
	if err != nil {
		return ""
	}
	payload := string(payloadBytes)
	if pipeIdx := strings.IndexByte(payload, '|'); pipeIdx >= 0 {
		return payload[:pipeIdx]
	}
	return payload
}

// isDBError returns true for errors that are NOT known validation/auth errors.
// These indicate an internal server problem rather than invalid credentials.
func isDBError(err error) bool {
	switch err {
	case service.ErrInvalidConnectToken,
		service.ErrInvalidMachineAccessToken,
		service.ErrInvalidMachineToken,
		service.ErrInvalidTokenFormat,
		service.ErrTokenExpired,
		service.ErrMasterKeyRevoked,
		service.ErrMachineRevoked:
		return false
	default:
		return true
	}
}
