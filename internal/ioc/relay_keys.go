package ioc

import (
	"crypto/ed25519"
	"log"

	"github.com/LaLanMo/muxagent-relay/internal/config"
	"github.com/LaLanMo/muxagent-relay/internal/infra/crypto"
)

type RelaySigningKey struct {
	Private ed25519.PrivateKey
	Public  ed25519.PublicKey
}

func InitRelaySigningKey(cfg *config.Config) (*RelaySigningKey, error) {
	priv, pub, generated, err := crypto.LoadRelaySigningKey(cfg.Relay.SigningPrivateKey)
	if err != nil {
		return nil, err
	}
	if generated {
		log.Println("WARNING: RELAY_SIGNING_PRIVATE_KEY not set; generated ephemeral relay signing key")
	}
	return &RelaySigningKey{Private: priv, Public: pub}, nil
}

func RelaySignPrivate(key *RelaySigningKey) ed25519.PrivateKey {
	return key.Private
}

func RelaySignPublic(key *RelaySigningKey) ed25519.PublicKey {
	return key.Public
}
