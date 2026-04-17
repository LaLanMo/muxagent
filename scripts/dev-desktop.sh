#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI_DIR="$ROOT_DIR/cli"
DESKTOP_DIR="$ROOT_DIR/desktop"
DEV_ROOT="$ROOT_DIR/.muxagent/desktop-dev"
CLI_BIN_DIR="$DEV_ROOT/bin"
APP_SERVER_STATE_DIR="$DEV_ROOT/appserver"
TASK_HOME="$DEV_ROOT"
TASKCONFIG_ROOT="$DEV_ROOT/taskconfig"
APP_SERVER_DAEMON_STATE_PATH="$APP_SERVER_STATE_DIR/appserver-daemon-state.json"

if ! command -v go >/dev/null 2>&1; then
  echo "go is required to build the local muxagent CLI binary" >&2
  exit 1
fi

if ! command -v pnpm >/dev/null 2>&1; then
  echo "pnpm is required to launch desktop dev" >&2
  exit 1
fi

mkdir -p "$CLI_BIN_DIR" "$APP_SERVER_STATE_DIR" "$TASKCONFIG_ROOT"

CLI_BIN="$CLI_BIN_DIR/muxagent"
if [[ "${OS:-}" == "Windows_NT" ]]; then
  CLI_BIN="$CLI_BIN.exe"
fi

json_number_field() {
  local file="$1"
  local field="$2"
  sed -n "s/.*\"$field\"[[:space:]]*:[[:space:]]*\\([0-9][0-9]*\\).*/\\1/p" "$file" | head -n 1
}

pid_is_alive() {
  local pid="$1"
  [[ -n "$pid" ]] || return 1
  kill -0 "$pid" >/dev/null 2>&1
}

wait_for_process_exit() {
  local pid="$1"
  local attempts=50
  while (( attempts > 0 )); do
    if ! pid_is_alive "$pid"; then
      return 0
    fi
    sleep 0.1
    attempts=$((attempts - 1))
  done
  return 1
}

stop_pid_for_dev_restart() {
  local pid="$1"

  if ! pid_is_alive "$pid"; then
    return 0
  fi

  kill -TERM "$pid" >/dev/null 2>&1 || {
    echo "Failed to stop dev app-server PID $pid before launching desktop dev" >&2
    return 1
  }

  if wait_for_process_exit "$pid"; then
    return 0
  fi

  echo "Dev app-server PID $pid did not exit after SIGTERM; forcing shutdown" >&2
  kill -KILL "$pid" >/dev/null 2>&1 || {
    echo "Failed to force-stop dev app-server PID $pid before launching desktop dev" >&2
    return 1
  }

  if wait_for_process_exit "$pid"; then
    return 0
  fi

  echo "Dev app-server PID $pid is still alive after SIGKILL" >&2
  return 1
}

restart_dev_app_server_if_needed() {
  local state_path pid

  if [[ "${OS:-}" == "Windows_NT" ]]; then
    return 0
  fi

  state_path="$APP_SERVER_DAEMON_STATE_PATH"
  [[ -f "$state_path" ]] || return 0

  pid="$(json_number_field "$state_path" "pid")"
  if [[ -z "$pid" ]]; then
    rm -f "$state_path"
    return 0
  fi

  if ! pid_is_alive "$pid"; then
    rm -f "$state_path"
    return 0
  fi

  echo "Stopping existing dev app-server so desktop dev uses the freshly built CLI:"
  echo "  pid:   $pid"
  echo "  state: $state_path"

  stop_pid_for_dev_restart "$pid"

  if [[ -f "$state_path" ]] && ! pid_is_alive "$pid"; then
    rm -f "$state_path"
  fi
}

echo "Building muxagent CLI -> $CLI_BIN"
(
  cd "$CLI_DIR"
  go build -o "$CLI_BIN" ./cmd/muxagent
)

restart_dev_app_server_if_needed

echo "Launching desktop dev with:"
echo "  cli:   $CLI_BIN"
echo "  state: $APP_SERVER_STATE_DIR"
echo "  task:  $TASK_HOME"
echo "  cfg:   $TASKCONFIG_ROOT"

cd "$DESKTOP_DIR"
MUXAGENT_CLI_PATH="$CLI_BIN" \
MUXAGENT_APP_SERVER_STATE_DIR="$APP_SERVER_STATE_DIR" \
MUXAGENT_TASK_HOME="$TASK_HOME" \
MUXAGENT_TASKCONFIG_ROOT="$TASKCONFIG_ROOT" \
pnpm tauri:dev "$@"
