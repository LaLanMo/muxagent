package ioc

import (
	"crypto/ed25519"

	"github.com/LaLanMo/muxagent-relay/internal/config"
	"github.com/LaLanMo/muxagent-relay/internal/infra/crypto"
)

type RelaySigningKey struct {
	Private ed25519.PrivateKey
	Public  ed25519.PublicKey
}

func InitRelaySigningKey(cfg *config.Config) (*RelaySigningKey, error) {
	priv, pub, err := crypto.LoadRelaySigningKey(cfg.Relay.SigningPrivateKey)
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
