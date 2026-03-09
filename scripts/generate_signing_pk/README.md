Relay Signing Key Generator

Generates an Ed25519 keypair for relay message signing.

- Private key: set as `MUXAGENT_RELAY_SIGNING_PRIVATE_KEY` environment variable on the relay
- Public key: set as `relay_signing_public_key` in CLI config

Key format:

- Encoding: Base64 StdEncoding (not URL-safe, no PEM headers)
- Private key: 64 bytes raw (ed25519.PrivateKeySize), base64-encoded
- Public key: 32 bytes raw (ed25519.PublicKeySize), base64-encoded

Usage:

  go run .

Output:

  MUXAGENT_RELAY_SIGNING_PRIVATE_KEY=BASE64_ED25519_PRIVATE_KEY
  relay_signing_public_key=BASE64_ED25519_PUBLIC_KEY

Relay setup:

  export MUXAGENT_RELAY_SIGNING_PRIVATE_KEY=BASE64_ED25519_PRIVATE_KEY

CLI config:

  {
    "relay_url": "wss://relay.example/ws",
    "relay_signing_public_key": "BASE64_ED25519_PUBLIC_KEY"
  }

If MUXAGENT_RELAY_SIGNING_PRIVATE_KEY is empty or not set, relay startup fails.
