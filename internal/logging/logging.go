package logging

import (
	"context"
	"log/slog"
	"os"
	"time"
)

const (
	EventHTTPAccess            = "http.access"
	EventAuthRequestCreated    = "auth.request.created"
	EventAuthRequestApproved   = "auth.request.approved"
	EventAuthRequestRejected   = "auth.request.rejected"
	EventKeyringUpdateApplied  = "keyring.update.applied"
	EventKeyringUpdateRejected = "keyring.update.rejected"
	EventAuthzDenied           = "authz.denied"
	EventWSUpgradeRejected     = "ws.upgrade.rejected"
	EventWSClientRegistered    = "ws.client.registered"
	EventWSMachineRegistered   = "ws.machine.registered"
	EventWSRegistrationDenied  = "ws.registration.rejected"
	EventWSSessionRejected     = "ws.session.rejected"
	EventWSSessionStarted      = "ws.session.started"
	EventWSSessionEnded        = "ws.session.ended"
)

const (
	ResultSuccess  = "success"
	ResultRejected = "rejected"
	ResultDenied   = "denied"
	ResultError    = "error"
)

type clientIPContextKey struct{}

func InitDefaultLogger() {
	handler := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo})
	slog.SetDefault(slog.New(handler))
}

func WithClientIP(ctx context.Context, clientIP string) context.Context {
	if clientIP == "" {
		return ctx
	}
	return context.WithValue(ctx, clientIPContextKey{}, clientIP)
}

func ClientIP(ctx context.Context) string {
	if ctx == nil {
		return ""
	}
	clientIP, _ := ctx.Value(clientIPContextKey{}).(string)
	return clientIP
}

func Audit(ctx context.Context, level slog.Level, event, result, reason string, attrs ...slog.Attr) {
	logAttrs := []slog.Attr{
		slog.String("event", event),
		slog.String("result", result),
	}
	if reason != "" {
		logAttrs = append(logAttrs, slog.String("reason", reason))
	}
	if clientIP := ClientIP(ctx); clientIP != "" {
		logAttrs = append(logAttrs, slog.String("client_ip", clientIP))
	}
	logAttrs = append(logAttrs, attrs...)
	slog.LogAttrs(ctx, level, "audit", logAttrs...)
}

func HTTPAccess(ctx context.Context, method, path string, status int, latency time.Duration, attrs ...slog.Attr) {
	logAttrs := []slog.Attr{
		slog.String("event", EventHTTPAccess),
		slog.String("result", resultFromStatus(status)),
		slog.String("method", method),
		slog.String("path", path),
		slog.Int("status", status),
		slog.Int64("latency_ms", latency.Milliseconds()),
	}
	if clientIP := ClientIP(ctx); clientIP != "" {
		logAttrs = append(logAttrs, slog.String("client_ip", clientIP))
	}
	logAttrs = append(logAttrs, attrs...)
	slog.LogAttrs(ctx, slog.LevelInfo, "http access", logAttrs...)
}

func resultFromStatus(status int) string {
	switch {
	case status >= 500:
		return ResultError
	case status >= 400:
		return ResultDenied
	default:
		return ResultSuccess
	}
}
