package relayws

import (
	"context"

	"github.com/LaLanMo/muxagent/cli/internal/appwire"
)

func (c *Client) rpcSessionGitStatus(ctx context.Context, params appwire.SessionGitStatusParams) (any, string) {
	return c.agentChat().SessionGitStatus(ctx, params)
}
