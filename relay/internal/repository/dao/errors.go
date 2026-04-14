package dao

import (
	"errors"
	"strings"

	"gorm.io/gorm"
)

var (
	ErrRecordNotFound = errors.New("record not found")
	ErrDuplicateKey   = errors.New("duplicate key")
)

func normalizeDBError(err error) error {
	if err == nil {
		return nil
	}
	if errors.Is(err, gorm.ErrDuplicatedKey) {
		return ErrDuplicateKey
	}

	msg := strings.ToLower(err.Error())
	if strings.Contains(msg, "duplicate key value") || strings.Contains(msg, "unique constraint failed") {
		return ErrDuplicateKey
	}
	return err
}
