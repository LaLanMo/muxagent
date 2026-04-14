package api

import "github.com/LaLanMo/muxagent-relay/internal/errs"

// Envelope wraps all API responses with a standardized structure
type Envelope struct {
	Code    int         `json:"code"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}

// Error codes
const (
	CodeSuccess          = errs.CodeSuccess
	CodeInvalidRequest   = errs.CodeInvalidRequest
	CodeNotFound         = errs.CodeNotFound
	CodeInternalError    = errs.CodeInternalError
	CodeMethodNotAllowed = errs.CodeMethodNotAllowed
	CodeExpired          = errs.CodeExpired
	CodeConflict         = errs.CodeConflict
	CodeInvalidSignature = errs.CodeInvalidSignature
	CodeInvalidPublicKey = errs.CodeInvalidPublicKey
	CodeRevoked          = errs.CodeRevoked
	CodeRateLimited      = errs.CodeRateLimited
	CodeUnauthorized     = errs.CodeUnauthorized
)
