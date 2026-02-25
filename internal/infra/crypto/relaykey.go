package crypto

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"fmt"
)

// LoadRelaySigningKey loads the relay signing keypair from config.
// If no key is provided, it generates a new keypair.
// Returns private key, public key, and a boolean indicating whether it was generated.
func LoadRelaySigningKey(privB64 string) (ed25519.PrivateKey, ed25519.PublicKey, bool, error) {
	if privB64 == "" {
		pub, priv, err := ed25519.GenerateKey(rand.Reader)
		if err != nil {
			return nil, nil, false, err
		}
		return priv, pub, true, nil
	}

	decoded, err := base64.StdEncoding.DecodeString(privB64)
	if err != nil {
		return nil, nil, false, fmt.Errorf("invalid RELAY_SIGNING_PRIVATE_KEY: %w", err)
	}
	if len(decoded) != ed25519.PrivateKeySize {
		return nil, nil, false, fmt.Errorf("invalid RELAY_SIGNING_PRIVATE_KEY length")
	}
	priv := ed25519.PrivateKey(decoded)
	pub := priv.Public().(ed25519.PublicKey)
	return priv, pub, false, nil
}
