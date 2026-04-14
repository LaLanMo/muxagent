package domain

import (
	"time"

	"github.com/google/uuid"
)

// MasterKey represents a master device keypair.
type MasterKey struct {
	ID                              uuid.UUID
	MasterID                        uuid.UUID
	MasterSignKeyFingerprint        string
	MasterSignPub                   []byte
	MasterEncPub                    []byte
	CreatedAt                       time.Time
	RevokedAt                       *time.Time
	AddedByMasterSignKeyFingerprint *string
	KeyringSeqAdded                 int
}
