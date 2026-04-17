package gitstatus

import (
	"os"
	"strings"
)

// sanitizedEnv returns a minimal environment for a git child process.
//
// It strips every GIT_* variable inherited from the parent (most
// importantly GIT_DIR / GIT_WORK_TREE, which the app-server could have
// picked up from its launch directory) and injects a small set of safe
// defaults that prevent git from prompting or taking file locks.
func sanitizedEnv() []string {
	parent := os.Environ()
	out := make([]string, 0, len(parent)+4)
	for _, kv := range parent {
		key, _, ok := strings.Cut(kv, "=")
		if !ok {
			out = append(out, kv)
			continue
		}
		if strings.HasPrefix(key, "GIT_") {
			continue
		}
		out = append(out, kv)
	}
	out = append(out,
		"GIT_ASKPASS=/bin/true",
		"GIT_TERMINAL_PROMPT=0",
		"GIT_OPTIONAL_LOCKS=0",
		"LANG=C",
	)
	return out
}
