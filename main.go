package main

import (
	"log"

	"github.com/LaLanMo/muxagent-relay/internal/config"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatal(err)
	}
	app, err := InitApp(cfg)
	if err != nil {
		log.Fatal(err)
	}
	if app.AuthCleanup != nil {
		defer app.AuthCleanup()
	}

	log.Printf("Relay server on %s", cfg.Relay.ListenAddr)
	log.Println("  - Machine connections: /ws")
	log.Println("  - Client connections:  /ws")
	log.Println("  - Auth endpoints:      /v1/auth/*")
	log.Println("  - Keyring endpoints:   /v1/keyring/*")

	if err := app.Router.Run(cfg.Relay.ListenAddr); err != nil {
		log.Fatal(err)
	}
}
