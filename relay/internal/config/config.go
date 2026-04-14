package config

import (
	"fmt"
	"net"
	"net/url"
	"os"
	"strings"

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
		PublicBaseURL string `mapstructure:"public_base_url"`
		ListenAddr    string `mapstructure:"listen_addr"`
	} `mapstructure:"relay"`
	Firebase struct {
		CredentialsFile string `mapstructure:"credentials_file"`
	} `mapstructure:"firebase"`
	HTTP      HTTPConfig      `mapstructure:"http"`
	RateLimit RateLimitConfig `mapstructure:"rate_limit"`
}

type HTTPConfig struct {
	ReadHeaderTimeoutSec int   `mapstructure:"read_header_timeout_sec"`
	ReadTimeoutSec       int   `mapstructure:"read_timeout_sec"`
	WriteTimeoutSec      int   `mapstructure:"write_timeout_sec"`
	IdleTimeoutSec       int   `mapstructure:"idle_timeout_sec"`
	MaxHeaderBytes       int   `mapstructure:"max_header_bytes"`
	MaxJSONBodyBytes     int64 `mapstructure:"max_json_body_bytes"`
}

type RateLimitConfig struct {
	// Per-IP HTTP rate limits (token bucket, requests/min)
	AuthCreatePerIPPerMin int `mapstructure:"auth_create_per_ip_per_min"`
	ReadPerIPPerMin       int `mapstructure:"read_per_ip_per_min"`
	WritePerIPPerMin      int `mapstructure:"write_per_ip_per_min"`
	WSUpgradePerIPPerMin  int `mapstructure:"ws_upgrade_per_ip_per_min"`

	// WS connection caps
	MaxWSConnsPerIP int `mapstructure:"max_ws_conns_per_ip"`
	MaxWSConnsTotal int `mapstructure:"max_ws_conns_total"`

	// Per-connection WS inbound bandwidth (bytes/min)
	WSInboundBytesPerConnPerMin int64 `mapstructure:"ws_inbound_bytes_per_conn_per_min"`

	// WS registration deadline (seconds); unregistered connections are dropped after this
	WSRegisterTimeoutSec int `mapstructure:"ws_register_timeout_sec"`

	TrustedProxies []string `mapstructure:"trusted_proxies"`
}

// WithDefaults fills zero-valued fields with production defaults sized for
// a single 4C8G instance serving ~1000 concurrent users (~3000 WS conns).
func (c RateLimitConfig) WithDefaults() RateLimitConfig {
	if c.AuthCreatePerIPPerMin <= 0 {
		c.AuthCreatePerIPPerMin = 20
	}
	if c.ReadPerIPPerMin <= 0 {
		c.ReadPerIPPerMin = 200 // CLI polls at 0.5Hz + mobile keyring queries
	}
	if c.WritePerIPPerMin <= 0 {
		c.WritePerIPPerMin = 60
	}
	if c.WSUpgradePerIPPerMin <= 0 {
		c.WSUpgradePerIPPerMin = 30 // reconnect storms
	}
	if c.MaxWSConnsPerIP <= 0 {
		c.MaxWSConnsPerIP = 50 // NAT/corporate: many users behind one IP
	}
	if c.MaxWSConnsTotal <= 0 {
		c.MaxWSConnsTotal = 5000 // ~1000 users × (1 client + 2 machines) + headroom
	}
	if c.WSInboundBytesPerConnPerMin <= 0 {
		c.WSInboundBytesPerConnPerMin = 50 * 1024 * 1024 // 50MB per conn
	}
	if c.WSRegisterTimeoutSec <= 0 {
		c.WSRegisterTimeoutSec = 10
	}
	return c
}

func (c HTTPConfig) WithDefaults() HTTPConfig {
	if c.ReadHeaderTimeoutSec <= 0 {
		c.ReadHeaderTimeoutSec = 5
	}
	if c.ReadTimeoutSec <= 0 {
		c.ReadTimeoutSec = 15
	}
	if c.WriteTimeoutSec <= 0 {
		c.WriteTimeoutSec = 30
	}
	if c.IdleTimeoutSec <= 0 {
		c.IdleTimeoutSec = 60
	}
	if c.MaxHeaderBytes <= 0 {
		c.MaxHeaderBytes = 16 * 1024
	}
	if c.MaxJSONBodyBytes <= 0 {
		c.MaxJSONBodyBytes = 64 * 1024
	}
	return c
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
	config.RateLimit = config.RateLimit.WithDefaults()
	config.HTTP = config.HTTP.WithDefaults()
	if err := config.Validate(); err != nil {
		return nil, err
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

func (c *Config) Validate() error {
	if strings.TrimSpace(c.Relay.PublicBaseURL) == "" {
		return fmt.Errorf("relay.public_base_url is required")
	}

	publicURL, err := url.Parse(c.Relay.PublicBaseURL)
	if err != nil {
		return fmt.Errorf("invalid relay.public_base_url: %w", err)
	}
	if publicURL.Scheme == "" || publicURL.Hostname() == "" {
		return fmt.Errorf("invalid relay.public_base_url: missing scheme or host")
	}

	loopback := isLoopbackHost(publicURL.Hostname())
	if !loopback {
		if !strings.EqualFold(publicURL.Scheme, "https") {
			return fmt.Errorf("relay.public_base_url must use https for non-loopback hosts")
		}
		if len(c.RateLimit.TrustedProxies) == 0 {
			return fmt.Errorf("rate_limit.trusted_proxies must be configured for non-loopback relay.public_base_url")
		}
	}

	return nil
}

func isLoopbackHost(host string) bool {
	if strings.EqualFold(host, "localhost") {
		return true
	}
	ip := net.ParseIP(host)
	return ip != nil && ip.IsLoopback()
}
