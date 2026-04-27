package appserver

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"
	"time"
)

const agentChatDaemonEnsureTimeout = 12 * time.Second

func bestEffortEnsureAgentChatDaemon(ctx context.Context, errOut io.Writer) {
	if ctx == nil {
		ctx = context.Background()
	}
	if errOut == nil {
		errOut = io.Discard
	}
	exe, err := os.Executable()
	if err != nil {
		fmt.Fprintf(errOut, "Agent Chat daemon unavailable: resolve executable: %v\n", err)
		return
	}

	ensureCtx, cancel := context.WithTimeout(ctx, agentChatDaemonEnsureTimeout)
	defer cancel()

	var stderr bytes.Buffer
	cmd := exec.CommandContext(ensureCtx, exe, "daemon", "ensure")
	cmd.Stdout = io.Discard
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		detail := strings.TrimSpace(stderr.String())
		if detail != "" {
			fmt.Fprintf(errOut, "Agent Chat daemon unavailable: %v: %s\n", err, detail)
			return
		}
		fmt.Fprintf(errOut, "Agent Chat daemon unavailable: %v\n", err)
	}
}
