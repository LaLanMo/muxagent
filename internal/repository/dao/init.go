package dao

import "gorm.io/gorm"

// AutoMigrate migrates all v1 models. v2 ciphertext tables are intentionally omitted.
func AutoMigrate(db *gorm.DB) error {
	return db.AutoMigrate(
		&MasterIdentity{},
		&MasterKey{},
		&Machine{},
		&AuthRequest{},
		&KeyringUpdate{},
		&DeviceToken{},
	)
}
