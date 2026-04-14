package crypto

import (
	"crypto/sha256"
	"encoding/base64"
)

// HashKeyFingerprint returns a stable fingerprint for a public key.
// Uses SHA-256 and base64url encoding without padding.
func HashKeyFingerprint(pub []byte) string {
	sum := sha256.Sum256(pub)
	return base64.RawURLEncoding.EncodeToString(sum[:])
}

// HashBytes returns a stable hash for arbitrary payload bytes.
// Uses SHA-256 and base64url encoding without padding.
func HashBytes(data []byte) string {
	sum := sha256.Sum256(data)
	return base64.RawURLEncoding.EncodeToString(sum[:])
}
