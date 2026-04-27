package appserver

import (
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestAppServerDoesNotOwnAgentChatRuntime(t *testing.T) {
	forbidden := map[string]string{
		"github.com/LaLanMo/muxagent/cli/internal/agentchat":       "app-server must proxy daemon-owned agentchat instead of constructing its own service",
		"github.com/LaLanMo/muxagent/cli/internal/runtime/manager": "app-server must not create the agentchat ACP runtime manager",
	}

	entries, err := os.ReadDir(".")
	if err != nil {
		t.Fatalf("read appserver package: %v", err)
	}
	fset := token.NewFileSet()
	for _, entry := range entries {
		name := entry.Name()
		if entry.IsDir() || !strings.HasSuffix(name, ".go") || strings.HasSuffix(name, "_test.go") {
			continue
		}
		file, err := parser.ParseFile(fset, filepath.Join(".", name), nil, parser.ImportsOnly)
		if err != nil {
			t.Fatalf("parse %s: %v", name, err)
		}
		for _, imported := range file.Imports {
			path := strings.Trim(imported.Path.Value, `"`)
			if message, ok := forbidden[path]; ok {
				t.Fatalf("%s imports %s: %s", name, path, message)
			}
		}
	}
}
