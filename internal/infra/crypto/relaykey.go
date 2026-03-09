package crypto

import (
	"crypto/ed25519"
	"encoding/base64"
	"fmt"
)

// LoadRelaySigningKey loads the relay signing keypair from config.
func LoadRelaySigningKey(privB64 string) (ed25519.PrivateKey, ed25519.PublicKey, error) {
	if privB64 == "" {
		return nil, nil, fmt.Errorf("missing RELAY_SIGNING_PRIVATE_KEY")
	}

	decoded, err := base64.StdEncoding.DecodeString(privB64)
	if err != nil {
		return nil, nil, fmt.Errorf("invalid RELAY_SIGNING_PRIVATE_KEY: %w", err)
	}
	if len(decoded) != ed25519.PrivateKeySize {
		return nil, nil, fmt.Errorf("invalid RELAY_SIGNING_PRIVATE_KEY length")
	}
	priv := ed25519.PrivateKey(decoded)
	pub := priv.Public().(ed25519.PublicKey)
	return priv, pub, nil
}
