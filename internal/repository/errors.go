package repository

import "errors"

var (
	ErrAuthRequestNotFound    = errors.New("auth request not found")
	ErrMasterIdentityNotFound = errors.New("master identity not found")
	ErrMasterKeyNotFound      = errors.New("master key not found")
	ErrMachineNotFound        = errors.New("machine not found")
	ErrKeyringUpdateNotFound  = errors.New("keyring update not found")
)
