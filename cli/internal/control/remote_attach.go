package control

import "time"

type AttachSessionRequest struct {
	SessionID string `json:"session_id"`
	Runtime   string `json:"runtime"`
	CWD       string `json:"cwd,omitempty"`
	Title     string `json:"title,omitempty"`
}

type AttachSessionResponse struct {
	OK          bool      `json:"ok"`
	SessionID   string    `json:"session_id"`
	Runtime     string    `json:"runtime"`
	CWD         string    `json:"cwd"`
	Title       string    `json:"title,omitempty"`
	Status      string    `json:"status"`
	CreatedAt   time.Time `json:"created_at,omitempty"`
	UpdatedAt   time.Time `json:"updated_at,omitempty"`
	Broadcasted bool      `json:"broadcasted"`
}
