package api

import (
	"errors"
	"net/http"
	"strings"

	"github.com/LaLanMo/muxagent-relay/internal/service"
	"github.com/gin-gonic/gin"
)

func writeJSONDecodeError(c *gin.Context, err error) {
	var maxBytesErr *http.MaxBytesError
	if errors.As(err, &maxBytesErr) || strings.Contains(strings.ToLower(err.Error()), "request body too large") {
		c.JSON(http.StatusRequestEntityTooLarge, Envelope{Code: CodeInvalidRequest, Message: "request body too large"})
		return
	}
	c.JSON(http.StatusBadRequest, Envelope{Code: CodeInvalidRequest, Message: "invalid JSON"})
}

func validateHostname(hostname string) error {
	if len(hostname) > service.MaxHostnameBytes {
		return errors.New("hostname too long")
	}
	return nil
}
