package sessionattach

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/LaLanMo/muxagent/cli/internal/appwire"
	"github.com/LaLanMo/muxagent/cli/internal/domain"
)

var (
	ErrRuntimeRequired   = errors.New("missing runtime")
	ErrSessionIDRequired = errors.New("missing session id")
	ErrPublisherRequired = errors.New("relay not connected")
)

type Publisher interface {
	SendLiveEvent(event appwire.Event) error
	MachineID() string
}

type Request struct {
	SessionID string
	Runtime   string
}

type Result struct {
	SessionID string
	Runtime   string
	CWD       string
	Title     string
	Status    domain.SessionStatus
	CreatedAt time.Time
	UpdatedAt time.Time
}

func Execute(
	ctx context.Context,
	registry *Registry,
	publisher Publisher,
	req Request,
) (Result, error) {
	runtimeID := strings.TrimSpace(req.Runtime)
	if runtimeID == "" {
		return Result{}, ErrRuntimeRequired
	}
	sessionID := strings.TrimSpace(req.SessionID)
	if sessionID == "" {
		return Result{}, ErrSessionIDRequired
	}
	if publisher == nil {
		return Result{}, ErrPublisherRequired
	}

	resolvers := registry
	if resolvers == nil {
		resolvers = NewRegistry()
	}
	meta, err := resolvers.Resolve(runtimeID, sessionID)
	if err != nil {
		return Result{}, err
	}
	if strings.TrimSpace(meta.CWD) == "" {
		return Result{}, ErrMissingCWD
	}

	updatedAt := meta.UpdatedAt
	if updatedAt.IsZero() {
		updatedAt = time.Now().UTC()
	}
	createdAt := meta.CreatedAt
	if createdAt.IsZero() {
		createdAt = updatedAt
	}

	result := Result{
		SessionID: sessionID,
		Runtime:   runtimeID,
		CWD:       meta.CWD,
		Title:     meta.Title,
		Status:    domain.SessionStatusIdle,
		CreatedAt: createdAt,
		UpdatedAt: updatedAt,
	}
	if err := publishStatus(ctx, publisher, result); err != nil {
		return Result{}, err
	}
	return result, nil
}

func publishStatus(_ context.Context, publisher Publisher, result Result) error {
	if publisher == nil {
		return ErrPublisherRequired
	}
	return publisher.SendLiveEvent(appwire.Event{
		Type:      appwire.EventSessionStatus,
		SessionID: result.SessionID,
		At:        time.Now().UTC(),
		SessionInfo: &appwire.SessionStatusEvent{
			App: appwire.SessionStatusEventApp{
				ID:        result.SessionID,
				Title:     result.Title,
				Status:    appwire.SessionStatus(result.Status),
				MachineID: strings.TrimSpace(publisher.MachineID()),
				Runtime:   result.Runtime,
				CWD:       result.CWD,
				CreatedAt: result.CreatedAt,
				UpdatedAt: result.UpdatedAt,
			},
		},
	})
}
