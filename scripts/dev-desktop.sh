#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI_DIR="$ROOT_DIR/cli"
DESKTOP_DIR="$ROOT_DIR/desktop"
DEV_ROOT="$ROOT_DIR/.muxagent/desktop-dev"
CLI_BIN_DIR="$DEV_ROOT/bin"
APP_SERVER_STATE_DIR="$DEV_ROOT/appserver"

if ! command -v go >/dev/null 2>&1; then
  echo "go is required to build the local muxagent CLI binary" >&2
  exit 1
fi

if ! command -v pnpm >/dev/null 2>&1; then
  echo "pnpm is required to launch desktop dev" >&2
  exit 1
fi

mkdir -p "$CLI_BIN_DIR" "$APP_SERVER_STATE_DIR"

CLI_BIN="$CLI_BIN_DIR/muxagent"
if [[ "${OS:-}" == "Windows_NT" ]]; then
  CLI_BIN="$CLI_BIN.exe"
fi

echo "Building muxagent CLI -> $CLI_BIN"
(
  cd "$CLI_DIR"
  go build -o "$CLI_BIN" ./cmd/muxagent
)

echo "Launching desktop dev with:"
echo "  cli:   $CLI_BIN"
echo "  state: $APP_SERVER_STATE_DIR"

cd "$DESKTOP_DIR"
MUXAGENT_CLI_PATH="$CLI_BIN" \
MUXAGENT_APP_SERVER_STATE_DIR="$APP_SERVER_STATE_DIR" \
pnpm tauri:dev "$@"
