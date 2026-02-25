package domain

import (
	"time"

	"github.com/google/uuid"
)

// Machine represents a paired CLI/daemon device.
type Machine struct {
	ID                        uuid.UUID
	MasterID                  uuid.UUID
	MachineSignKeyFingerprint string
	MachineSignPub            []byte
	MachineEncPub             []byte
	Hostname                  string
	CreatedAt                 time.Time
	LastSeenAt                time.Time
	RevokedAt                 *time.Time
}
