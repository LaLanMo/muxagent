package ioc

import (
	"github.com/LaLanMo/muxagent/relay/internal/config"
	"github.com/LaLanMo/muxagent/relay/internal/infra/db"
	"github.com/LaLanMo/muxagent/relay/internal/repository/dao"
	"gorm.io/gorm"
)

func InitDB(cfg *config.Config) (*gorm.DB, error) {
	dbConn, err := db.Connect(cfg.GetDatabaseDSN())
	if err != nil {
		return nil, err
	}
	if err := dao.AutoMigrate(dbConn); err != nil {
		return nil, err
	}
	return dbConn, nil
}
