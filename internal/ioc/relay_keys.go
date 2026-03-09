package ioc

import (
	"crypto/ed25519"
	"os"

	"github.com/LaLanMo/muxagent-relay/internal/infra/crypto"
)

type RelaySigningKey struct {
	Private ed25519.PrivateKey
	Public  ed25519.PublicKey
}

func InitRelaySigningKey() (*RelaySigningKey, error) {
	privB64 := os.Getenv("MUXAGENT_RELAY_SIGNING_PRIVATE_KEY")
	priv, pub, err := crypto.LoadRelaySigningKey(privB64)
	if err != nil {
		return nil, err
	}
	return &RelaySigningKey{Private: priv, Public: pub}, nil
}

func RelaySignPrivate(key *RelaySigningKey) ed25519.PrivateKey {
	return key.Private
}

func RelaySignPublic(key *RelaySigningKey) ed25519.PublicKey {
	return key.Public
}
