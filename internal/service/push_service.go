package service

import (
	"context"
	"log"

	"firebase.google.com/go/v4/messaging"
	"github.com/LaLanMo/muxagent-relay/internal/repository"
	"github.com/google/uuid"
)

type EventHint struct {
	Event string
}

type PushService interface {
	SendPushIfOffline(ctx context.Context, masterID uuid.UUID, hint EventHint) error
}

type pushServiceImpl struct {
	deviceTokens repository.DeviceTokenRepository
	hub          *WSHub
	fcm          *messaging.Client
}

type noopPushService struct{}

func NewPushService(deviceTokens repository.DeviceTokenRepository, hub *WSHub, fcm *messaging.Client) PushService {
	if fcm == nil {
		return &noopPushService{}
	}
	return &pushServiceImpl{
		deviceTokens: deviceTokens,
		hub:          hub,
		fcm:          fcm,
	}
}

func (s *noopPushService) SendPushIfOffline(ctx context.Context, masterID uuid.UUID, hint EventHint) error {
	return nil
}

func (s *pushServiceImpl) SendPushIfOffline(ctx context.Context, masterID uuid.UUID, hint EventHint) error {
	clients := s.hub.GetClientsByMasterID(masterID)
	if len(clients) > 0 {
		return nil
	}

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
					log.Printf("failed to delete stale device token: %v", delErr)
				}
			} else {
				log.Printf("FCM send failed: %v", err)
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
		return "Task Failed", "An agent task has failed"
	case "run.finished":
		return "Task Completed", "An agent task has completed"
	default:
		return "Agent Update", "Your agent has an update"
	}
}
