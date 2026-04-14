package crypto

import (
	"crypto/ed25519"
	"encoding/base64"
	"fmt"
	"strconv"
	"strings"
)

// VerifySignature verifies an Ed25519 signature.
// publicKey, message, and signature should be the raw bytes.
func VerifySignature(publicKey, message, signature []byte) bool {
	if len(publicKey) != ed25519.PublicKeySize {
		return false
	}
	if len(signature) != ed25519.SignatureSize {
		return false
	}
	return ed25519.Verify(publicKey, message, signature)
}

// SignMessage signs a message with an Ed25519 private key.
func SignMessage(privateKey ed25519.PrivateKey, message []byte) []byte {
	return ed25519.Sign(privateKey, message)
}

// SignMessageBase64 signs a message and returns a base64-encoded signature.
func SignMessageBase64(privateKey ed25519.PrivateKey, message []byte) string {
	sig := SignMessage(privateKey, message)
	return base64.StdEncoding.EncodeToString(sig)
}

// VerifySignatureBase64 verifies an Ed25519 signature using base64-encoded inputs.
func VerifySignatureBase64(publicKeyB64, messageStr, signatureB64 string) (bool, error) {
	publicKey, err := base64.StdEncoding.DecodeString(publicKeyB64)
	if err != nil {
		return false, fmt.Errorf("invalid public key encoding: %w", err)
	}

	signature, err := base64.StdEncoding.DecodeString(signatureB64)
	if err != nil {
		return false, fmt.Errorf("invalid signature encoding: %w", err)
	}

	return VerifySignature(publicKey, []byte(messageStr), signature), nil
}

// BuildSignatureMessage constructs the message to sign for registration.
// Format: machineID + ":" + timestamp
func BuildSignatureMessage(machineID string, timestamp int64) string {
	return fmt.Sprintf("%s:%d", machineID, timestamp)
}

// BuildApprovalMessage constructs the master approval message.
// Format: muxagent-approve-v1|request_id|machine_sign_pub|machine_enc_pub|relay_challenge|expires_at
func BuildApprovalMessage(requestID, machineSignPubB64, machineEncPubB64, relayChallengeB64 string, expiresAt int64) string {
	return strings.Join([]string{
		"muxagent-approve-v1",
		requestID,
		machineSignPubB64,
		machineEncPubB64,
		relayChallengeB64,
		strconv.FormatInt(expiresAt, 10),
	}, "|")
}

// BuildMachineAuthMessage constructs the machine auth challenge message.
// Format: muxagent-machine-auth-v1|machine_id|nonce
func BuildMachineAuthMessage(machineID, nonceB64 string) string {
	return strings.Join([]string{
		"muxagent-machine-auth-v1",
		machineID,
		nonceB64,
	}, "|")
}

// BuildSessionInitMessage constructs the session-init signing message.
// Format: muxagent-session-init-v1|machine_id|client_ephemeral_pub
func BuildSessionInitMessage(machineID, clientEphemeralPubB64 string) string {
	return strings.Join([]string{
		"muxagent-session-init-v1",
		machineID,
		clientEphemeralPubB64,
	}, "|")
}

// BuildSessionAckMessage constructs the session-ack signing message.
// Format: muxagent-session-ack-v1|machine_id|machine_ephemeral_pub
func BuildSessionAckMessage(machineID, machineEphemeralPubB64 string) string {
	return strings.Join([]string{
		"muxagent-session-ack-v1",
		machineID,
		machineEphemeralPubB64,
	}, "|")
}

// KeyringUpdatePayload represents a signed keyring update payload.
type KeyringUpdatePayload struct {
	MasterID                       string
	Seq                            int
	PrevHash                       string
	Action                         string
	TargetMasterSignPub            string
	TargetMasterEncPub             string
	SignerMasterSignKeyFingerprint string
}

// BuildKeyringUpdateMessage constructs the keyring update message.
// Format: muxagent-keyring-update-v1|master_id|seq|prev_hash|action|target_master_sign_pub|target_master_enc_pub|signer_master_sign_key_fingerprint
func BuildKeyringUpdateMessage(payload KeyringUpdatePayload) string {
	return strings.Join([]string{
		"muxagent-keyring-update-v1",
		payload.MasterID,
		strconv.Itoa(payload.Seq),
		payload.PrevHash,
		payload.Action,
		payload.TargetMasterSignPub,
		payload.TargetMasterEncPub,
		payload.SignerMasterSignKeyFingerprint,
	}, "|")
}
