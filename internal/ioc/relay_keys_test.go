package ioc

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"testing"
)

func TestInitRelaySigningKey_EnvPresent(t *testing.T) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("GenerateKey: %v", err)
	}

	t.Setenv("MUXAGENT_RELAY_SIGNING_PRIVATE_KEY", base64.StdEncoding.EncodeToString(priv))

	key, err := InitRelaySigningKey()
	if err != nil {
		t.Fatalf("InitRelaySigningKey: %v", err)
	}
	if !key.Public.Equal(pub) {
		t.Fatal("public key mismatch")
	}
}

func TestInitRelaySigningKey_EnvMissing(t *testing.T) {
	t.Setenv("MUXAGENT_RELAY_SIGNING_PRIVATE_KEY", "")

	_, err := InitRelaySigningKey()
	if err == nil {
		t.Fatal("expected error when env var is empty")
	}
	if err.Error() != "missing MUXAGENT_RELAY_SIGNING_PRIVATE_KEY" {
		t.Fatalf("unexpected error: %v", err)
	}
}
