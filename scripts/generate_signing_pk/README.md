relay.signing_private_key format

- Encoding: Base64 StdEncoding (not URL-safe, no PEM headers)
- Key type: Ed25519 private key
- Length: 64 bytes raw (ed25519.PrivateKeySize), then base64-encoded

Recommended: generate a raw Ed25519 key and store its base64 form in config.

Example (Go):

  go run .

This prints a single line that you can paste into config:

  {
    "relay": {
      "signing_private_key": "BASE64_ED25519_PRIVATE_KEY"
    }
  }

If relay.signing_private_key is empty, relay will generate an ephemeral key at
startup (not recommended for production).
