package main

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"fmt"
)

func main() {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		panic(err)
	}

	fmt.Printf("relay.signing_private_key=%s\n", base64.StdEncoding.EncodeToString(priv))
	fmt.Printf("relay_signing_public_key=%s\n", base64.StdEncoding.EncodeToString(pub))
}
