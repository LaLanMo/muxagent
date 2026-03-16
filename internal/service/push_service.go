package service

import (
	"context"
	"log/slog"

	"firebase.google.com/go/v4/messaging"
	"github.com/LaLanMo/muxagent-relay/internal/repository"
	"github.com/google/uuid"
)

type EventHint struct {
	Event string
}

type PushService interface {
	SendPushForHint(ctx context.Context, masterID uuid.UUID, hint EventHint) error
}

type pushServiceImpl struct {
	deviceTokens repository.DeviceTokenRepository
	fcm          *messaging.Client
}

type noopPushService struct{}

func NewPushService(deviceTokens repository.DeviceTokenRepository, fcm *messaging.Client) PushService {
	if fcm == nil {
		return &noopPushService{}
	}
	return &pushServiceImpl{
		deviceTokens: deviceTokens,
		fcm:          fcm,
	}
}

func (s *noopPushService) SendPushForHint(ctx context.Context, masterID uuid.UUID, hint EventHint) error {
	return nil
}

func (s *pushServiceImpl) SendPushForHint(ctx context.Context, masterID uuid.UUID, hint EventHint) error {
	tokens, err := s.deviceTokens.FindByMasterID(ctx, masterID)
	if err != nil {
		return err
	}
	if len(tokens) == 0 {
		return nil
	}

	title, body := pushContentForEvent(hint.Event)

	for _, dt := range tokens {
		msg := &messaging.Message{
			Token: dt.Token,
			Notification: &messaging.Notification{
				Title: title,
				Body:  body,
			},
			Data: map[string]string{
				"event": hint.Event,
			},
		}
		if _, err := s.fcm.Send(ctx, msg); err != nil {
			if messaging.IsUnregistered(err) {
				if delErr := s.deviceTokens.DeleteByToken(ctx, dt.Token); delErr != nil {
					slog.Warn("failed to delete stale device token", slog.Any("err", delErr), slog.String("master_id", masterID.String()))
				}
			} else {
				slog.Warn("fcm send failed", slog.Any("err", err), slog.String("master_id", masterID.String()), slog.String("event", hint.Event))
			}
		}
	}

	return nil
}

func pushContentForEvent(event string) (title, body string) {
	switch event {
	case "approval.requested":
		return "Approval Needed", "An agent is waiting for your approval"
	case "run.failed":
		return "Run Failed", "An agent run has failed"
	case "run.finished":
		return "Run Completed", "An agent run has completed"
	default:
		return "Agent Update", "Your agent has an update"
	}
}
