package config

import (
	"fmt"
	"os"

	"github.com/spf13/viper"
)

type Config struct {
	Database struct {
		Host     string `mapstructure:"host"`
		Port     int    `mapstructure:"port"`
		User     string `mapstructure:"user"`
		Password string `mapstructure:"password"`
		DBName   string `mapstructure:"dbname"`
		SSLMode  string `mapstructure:"sslmode"`
	} `mapstructure:"database"`
	Relay struct {
		PublicBaseURL     string `mapstructure:"public_base_url"`
		ListenAddr        string `mapstructure:"listen_addr"`
		SigningPrivateKey string `mapstructure:"signing_private_key"`
	} `mapstructure:"relay"`
	Firebase struct {
		CredentialsFile string `mapstructure:"credentials_file"`
	} `mapstructure:"firebase"`
}

func Load() (*Config, error) {
	v := viper.New()
	v.SetConfigType("json")

	if _, err := os.Stat("/mnt/secrets/prod"); err == nil {
		v.SetConfigFile("/mnt/secrets/prod")
		if err := v.ReadInConfig(); err != nil {
			return nil, fmt.Errorf("failed to read config file: %w", err)
		}
	} else {
		v.SetConfigName("local")
		v.AddConfigPath("./config")
		if err := v.ReadInConfig(); err != nil {
			return nil, fmt.Errorf("failed to read config file: %w", err)
		}
	}

	var config Config
	if err := v.Unmarshal(&config); err != nil {
		return nil, fmt.Errorf("failed to unmarshal config: %w", err)
	}

	return &config, nil
}

func (c *Config) GetDatabaseDSN() string {
	return fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		c.Database.Host,
		c.Database.Port,
		c.Database.User,
		c.Database.Password,
		c.Database.DBName,
		c.Database.SSLMode,
	)
}
