package crypto

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"testing"
)

func TestLoadRelaySigningKey_Valid(t *testing.T) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("GenerateKey: %v", err)
	}

	gotPriv, gotPub, err := LoadRelaySigningKey(base64.StdEncoding.EncodeToString(priv))
	if err != nil {
		t.Fatalf("LoadRelaySigningKey: %v", err)
	}
	if !gotPriv.Equal(priv) {
		t.Fatal("private key mismatch")
	}
	if !gotPub.Equal(pub) {
		t.Fatal("public key mismatch")
	}
}

func TestLoadRelaySigningKey_Empty(t *testing.T) {
	_, _, err := LoadRelaySigningKey("")
	if err == nil {
		t.Fatal("expected error for empty input")
	}
	if err.Error() != "missing MUXAGENT_RELAY_SIGNING_PRIVATE_KEY" {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestLoadRelaySigningKey_InvalidBase64(t *testing.T) {
	_, _, err := LoadRelaySigningKey("not-valid-base64!!!")
	if err == nil {
		t.Fatal("expected error for invalid base64")
	}
	want := "invalid MUXAGENT_RELAY_SIGNING_PRIVATE_KEY"
	if len(err.Error()) < len(want) || err.Error()[:len(want)] != want {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestLoadRelaySigningKey_WrongLength(t *testing.T) {
	short := make([]byte, 32)
	_, _, err := LoadRelaySigningKey(base64.StdEncoding.EncodeToString(short))
	if err == nil {
		t.Fatal("expected error for wrong length")
	}
	if err.Error() != "invalid MUXAGENT_RELAY_SIGNING_PRIVATE_KEY length" {
		t.Fatalf("unexpected error: %v", err)
	}
}
