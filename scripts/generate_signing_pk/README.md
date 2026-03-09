relay.signing_private_key format

- Encoding: Base64 StdEncoding (not URL-safe, no PEM headers)
- Key type: Ed25519 private key
- Length: 64 bytes raw (ed25519.PrivateKeySize), then base64-encoded

The paired CLI trust anchor is `relay_signing_public_key`:

- Encoding: Base64 StdEncoding
- Key type: Ed25519 public key
- Length: 32 bytes raw (ed25519.PublicKeySize), then base64-encoded

Recommended: generate a raw Ed25519 keypair once and distribute the private key
to relay config plus the matching public key to CLI config.

Example (Go):

  go run .

This prints two lines:

  relay.signing_private_key=BASE64_ED25519_PRIVATE_KEY
  relay_signing_public_key=BASE64_ED25519_PUBLIC_KEY

Example relay config:

  {
    "relay": {
      "signing_private_key": "BASE64_ED25519_PRIVATE_KEY"
    }
  }

Example CLI config:

  {
    "relay_url": "wss://relay.example/ws",
    "relay_signing_public_key": "BASE64_ED25519_PUBLIC_KEY"
  }

If relay.signing_private_key is empty or invalid, relay startup now fails.
