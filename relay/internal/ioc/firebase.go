package ioc

import (
	"context"
	"log/slog"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"github.com/LaLanMo/muxagent/relay/internal/config"
	"google.golang.org/api/option"
)

func InitFirebaseApp(cfg *config.Config) *firebase.App {
	if cfg.Firebase.CredentialsFile == "" {
		slog.Info("firebase disabled", slog.String("reason", "credentials_not_configured"))
		return nil
	}
	app, err := firebase.NewApp(context.Background(), nil, option.WithCredentialsFile(cfg.Firebase.CredentialsFile))
	if err != nil {
		slog.Warn("firebase init failed", slog.Any("err", err), slog.String("reason", "init_failed"))
		return nil
	}
	return app
}

func InitFCMClient(app *firebase.App) *messaging.Client {
	if app == nil {
		return nil
	}
	client, err := app.Messaging(context.Background())
	if err != nil {
		slog.Warn("fcm client init failed", slog.Any("err", err), slog.String("reason", "init_failed"))
		return nil
	}
	return client
}
