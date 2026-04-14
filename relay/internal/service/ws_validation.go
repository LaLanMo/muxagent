package service

import "errors"

func validateWSHostname(hostname string) error {
	if len(hostname) > MaxHostnameBytes {
		return errors.New("hostname too long")
	}
	return nil
}
