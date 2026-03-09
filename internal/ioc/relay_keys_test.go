package ioc

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"testing"

	"github.com/LaLanMo/muxagent-relay/internal/config"
)

func TestInitRelaySigningKey_RequiresConfiguredPrivateKey(t *testing.T) {
	cfg := &config.Config{}

	if _, err := InitRelaySigningKey(cfg); err == nil || err.Error() != "missing RELAY_SIGNING_PRIVATE_KEY" {
		t.Fatalf("error = %v, want missing RELAY_SIGNING_PRIVATE_KEY", err)
	}
}

func TestInitRelaySigningKey_LoadsConfiguredPrivateKey(t *testing.T) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("GenerateKey: %v", err)
	}

	cfg := &config.Config{}
	cfg.Relay.SigningPrivateKey = base64.StdEncoding.EncodeToString(priv)

	key, err := InitRelaySigningKey(cfg)
	if err != nil {
		t.Fatalf("InitRelaySigningKey: %v", err)
	}
	if got := base64.StdEncoding.EncodeToString(key.Public); got != base64.StdEncoding.EncodeToString(pub) {
		t.Fatalf("public key mismatch: got %q want %q", got, base64.StdEncoding.EncodeToString(pub))
	}
}
