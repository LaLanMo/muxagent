package service

import "time"

type KeyringState struct {
	MasterID string           `json:"master_id"`
	Seq      int              `json:"seq"`
	HeadHash string           `json:"head_hash"`
	Keys     []MasterKeyState `json:"keys"`
}

type MasterKeyState struct {
	MasterSignKeyFingerprint string     `json:"master_sign_key_fingerprint"`
	MasterSignPub            string     `json:"master_sign_pub"`
	MasterEncPub             string     `json:"master_enc_pub"`
	RevokedAt                *time.Time `json:"revoked_at,omitempty"`
}

type AuthStatus struct {
	State                              AuthStatusState `json:"state"`
	RequestID                          string          `json:"request_id"`
	MachineID                          string          `json:"machine_id"`
	MachineSignPub                     string          `json:"machine_sign_pub"`
	MachineEncPub                      string          `json:"machine_enc_pub"`
	MachineHostname                    string          `json:"machine_hostname,omitempty"`
	RelayChallenge                     string          `json:"relay_challenge"`
	ExpiresAt                          time.Time       `json:"expires_at"`
	ApprovedAt                         *time.Time      `json:"approved_at,omitempty"`
	ApprovedByMasterSignKeyFingerprint string          `json:"approved_by_master_sign_key_fingerprint,omitempty"`
	ApprovalSignature                  string          `json:"approval_signature,omitempty"`
	MasterID                           string          `json:"master_id,omitempty"`
	Keyring                            *KeyringState   `json:"keyring,omitempty"`
	RelayPubKey                        string          `json:"relay_pub_key,omitempty"`
	RelaySignature                     string          `json:"relay_signature,omitempty"`
}

type AuthStatusState string

const (
	AuthStatusPending  AuthStatusState = "pending"
	AuthStatusApproved AuthStatusState = "approved"
	AuthStatusExpired  AuthStatusState = "expired"
)

type AuthRequestResult struct {
	RequestID string    `json:"request_id"`
	QRURL     string    `json:"qr_url"`
	ExpiresAt time.Time `json:"expires_at"`
}

type KeyringAction string

const (
	KeyringActionAdd    KeyringAction = "add"
	KeyringActionRevoke KeyringAction = "revoke"
)

type KeyringUpdateInput struct {
	MasterID                       string
	Seq                            int
	PrevHash                       string
	Action                         KeyringAction
	TargetMasterSignPub            []byte
	TargetMasterEncPub             []byte
	SignerMasterSignKeyFingerprint string
	Signature                      []byte
}

type AuthApproveInput struct {
	MasterID          string
	MasterSignPub     []byte
	MasterEncPub      []byte
	ApprovalSignature []byte
	KeyringUpdate     *KeyringUpdateInput
}
