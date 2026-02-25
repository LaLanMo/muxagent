package domain

import (
	"time"

	"github.com/google/uuid"
)

// MasterIdentity represents a long-lived identity (keyring).
type MasterIdentity struct {
	ID        uuid.UUID
	CreatedAt time.Time
	RevokedAt *time.Time
	// KeyringSeq is the latest accepted KeyringUpdate sequence (starts at 1).
	KeyringSeq int
	// KeyringHeadHash is the hash of the newest (latest) KeyringUpdate.
	KeyringHeadHash string
}
