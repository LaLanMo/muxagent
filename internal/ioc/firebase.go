package ioc

import (
	"context"
	"log"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"github.com/LaLanMo/muxagent-relay/internal/config"
	"google.golang.org/api/option"
)

func InitFirebaseApp(cfg *config.Config) *firebase.App {
	if cfg.Firebase.CredentialsFile == "" {
		log.Println("Firebase credentials not configured, push notifications disabled")
		return nil
	}
	app, err := firebase.NewApp(context.Background(), nil, option.WithCredentialsFile(cfg.Firebase.CredentialsFile))
	if err != nil {
		log.Printf("Failed to initialize Firebase: %v, push notifications disabled", err)
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
		log.Printf("Failed to initialize FCM client: %v, push notifications disabled", err)
		return nil
	}
	return client
}
