package domain

import (
	"time"

	"github.com/google/uuid"
)

// AuthRequest represents a pending pairing request.
type AuthRequest struct {
	ID                                 uuid.UUID
	MachineID                          uuid.UUID
	MachineSignPub                     []byte
	MachineEncPub                      []byte
	Hostname                           string
	CreatedAt                          time.Time
	ExpiresAt                          time.Time
	RelayChallenge                     []byte
	ApprovedAt                         *time.Time
	ApprovedByMasterSignKeyFingerprint *string
	ApprovalSignature                  []byte
}
