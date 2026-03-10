package main

import (
	"log/slog"
	"os"

	"github.com/LaLanMo/muxagent-relay/internal/config"
	"github.com/LaLanMo/muxagent-relay/internal/logging"
)

func main() {
	logging.InitDefaultLogger()

	cfg, err := config.Load()
	if err != nil {
		slog.Error("failed to load config", slog.Any("err", err))
		os.Exit(1)
	}
	app, err := InitApp(cfg)
	if err != nil {
		slog.Error("failed to initialize app", slog.Any("err", err))
		os.Exit(1)
	}
	if app.AuthCleanup != nil {
		defer app.AuthCleanup()
	}

	slog.Info(
		"relay server starting",
		slog.String("listen_addr", cfg.Relay.ListenAddr),
		slog.String("machine_ws_path", "/ws"),
		slog.String("client_ws_path", "/ws"),
		slog.String("auth_path", "/v1/auth/*"),
		slog.String("keyring_path", "/v1/keyring/*"),
	)

	if err := app.Router.Run(cfg.Relay.ListenAddr); err != nil {
		slog.Error("relay server exited", slog.Any("err", err))
		os.Exit(1)
	}
}
