package domain

import (
	"time"

	"github.com/google/uuid"
)

// KeyringUpdate is an append-only signed update for a MasterIdentity keyring.
type KeyringUpdate struct {
	ID                             uuid.UUID
	MasterID                       uuid.UUID
	Seq                            int
	PrevHash                       string
	UpdateHash                     string
	Action                         string
	TargetMasterSignKeyFingerprint string
	TargetMasterSignPub            []byte
	TargetMasterEncPub             []byte
	SignerMasterSignKeyFingerprint string
	CreatedAt                      time.Time
	Signature                      []byte
}
