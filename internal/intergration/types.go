package intergration

type authRequestInput struct {
	MachineID      string `json:"machine_id"`
	MachineSignPub string `json:"machine_sign_pub"`
	MachineEncPub  string `json:"machine_enc_pub"`
}

type keyringUpdateInput struct {
	MasterID                       string `json:"master_id"`
	Seq                            int    `json:"seq"`
	PrevHash                       string `json:"prev_hash"`
	Action                         string `json:"action"`
	TargetMasterSignPub            string `json:"target_master_sign_pub"`
	TargetMasterEncPub             string `json:"target_master_enc_pub"`
	SignerMasterSignKeyFingerprint string `json:"signer_master_sign_key_fingerprint"`
	Signature                      string `json:"signature"`
}

type authApproveInput struct {
	MasterID          string              `json:"master_id"`
	MasterSignPub     string              `json:"master_sign_pub"`
	MasterEncPub      string              `json:"master_enc_pub"`
	ApprovalSignature string              `json:"approval_signature"`
	KeyringUpdate     *keyringUpdateInput `json:"keyring_update,omitempty"`
}

type keyringUpdateRequest struct {
	Seq                            int    `json:"seq"`
	PrevHash                       string `json:"prev_hash"`
	Action                         string `json:"action"`
	TargetMasterSignPub            string `json:"target_master_sign_pub"`
	TargetMasterEncPub             string `json:"target_master_enc_pub"`
	SignerMasterSignKeyFingerprint string `json:"signer_master_sign_key_fingerprint"`
	Signature                      string `json:"signature"`
}
