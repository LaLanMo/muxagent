package domain

import (
	"time"

	"github.com/google/uuid"
)

type DeviceToken struct {
	ID        uuid.UUID
	MasterID  uuid.UUID
	Token     string
	Platform  string
	CreatedAt time.Time
	UpdatedAt time.Time
}
