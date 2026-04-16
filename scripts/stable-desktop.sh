#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI_DIR="$ROOT_DIR/cli"
DESKTOP_DIR="$ROOT_DIR/desktop"
STABLE_ROOT="$ROOT_DIR/.muxagent/desktop-stable"
BIN_DIR="$STABLE_ROOT/bin"
MANIFEST_PATH="$STABLE_ROOT/manifest.json"
BUILD_MODE="${MUXAGENT_STABLE_BUILD_MODE:-debug}"
DEFAULT_MUXAGENT_ROOT="${HOME}/.muxagent"
DEFAULT_APP_SERVER_STATE_DIR="$DEFAULT_MUXAGENT_ROOT/appserver"
DEFAULT_APP_SERVER_DAEMON_STATE_PATH="$DEFAULT_APP_SERVER_STATE_DIR/appserver-daemon-state.json"

REFRESH=0
LAUNCH=1

usage() {
  cat <<'EOF'
Usage:
  scripts/stable-desktop.sh [--refresh] [--refresh-only] [app-args...]

Behavior:
  - Launches the pinned local stable desktop artifact from .muxagent/desktop-stable
  - Clears dev-only task profile overrides before launch
  - Uses the pinned stable CLI artifact instead of the host PATH

Options:
  --refresh       Rebuild the pinned stable artifacts from the current repo, then launch
  --refresh-only  Rebuild the pinned stable artifacts from the current repo, then exit
  -h, --help      Show this help

Environment:
  MUXAGENT_STABLE_BUILD_MODE=debug|release   Build profile used during refresh
EOF
}

APP_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --refresh)
      REFRESH=1
      shift
      ;;
    --refresh-only)
      REFRESH=1
      LAUNCH=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      APP_ARGS+=("$1")
      shift
      ;;
  esac
done

case "$BUILD_MODE" in
  debug|release)
    ;;
  *)
    echo "MUXAGENT_STABLE_BUILD_MODE must be 'debug' or 'release', got: $BUILD_MODE" >&2
    exit 1
    ;;
esac

CLI_BIN="$BIN_DIR/muxagent"
DESKTOP_BIN="$BIN_DIR/muxagent-desktop"
if [[ "${OS:-}" == "Windows_NT" ]]; then
  CLI_BIN="$BIN_DIR/muxagent.exe"
  DESKTOP_BIN="$BIN_DIR/muxagent-desktop.exe"
fi

json_number_field() {
  local file="$1"
  local field="$2"
  sed -n "s/.*\"$field\"[[:space:]]*:[[:space:]]*\\([0-9][0-9]*\\).*/\\1/p" "$file" | head -n 1
}

json_string_field() {
  local file="$1"
  local field="$2"
  sed -n "s/.*\"$field\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$file" | head -n 1
}

pid_is_alive() {
  local pid="$1"
  [[ -n "$pid" ]] || return 1
  kill -0 "$pid" >/dev/null 2>&1
}

process_command_path() {
  local pid="$1"
  ps -p "$pid" -o command= 2>/dev/null | awk 'NR == 1 { print $1 }'
}

current_cli_version() {
  "$CLI_BIN" --version 2>/dev/null | head -n 1 || true
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

stop_pid_for_stable_restart() {
  local pid="$1"

  if ! pid_is_alive "$pid"; then
    return 0
  fi

  kill -TERM "$pid" >/dev/null 2>&1 || {
    echo "Failed to stop default app-server PID $pid before launching stable desktop" >&2
    return 1
  }

  if wait_for_process_exit "$pid"; then
    return 0
  fi

  echo "Default app-server PID $pid did not exit after SIGTERM; forcing shutdown" >&2
  kill -KILL "$pid" >/dev/null 2>&1 || {
    echo "Failed to force-stop default app-server PID $pid before launching stable desktop" >&2
    return 1
  }

  if wait_for_process_exit "$pid"; then
    return 0
  fi

  echo "Default app-server PID $pid is still alive after SIGKILL" >&2
  return 1
}

maybe_restart_default_app_server() {
  local state_path pid daemon_cli_path daemon_cli_version pinned_cli_version restart_reason

  if [[ "${OS:-}" == "Windows_NT" ]]; then
    return 0
  fi

  state_path="$DEFAULT_APP_SERVER_DAEMON_STATE_PATH"
  [[ -f "$state_path" ]] || return 0

  pid="$(json_number_field "$state_path" "pid")"
  [[ -n "$pid" ]] || return 0

  if ! pid_is_alive "$pid"; then
    rm -f "$state_path"
    return 0
  fi

  daemon_cli_path="$(process_command_path "$pid")"
  daemon_cli_version="$(json_string_field "$state_path" "started_with_cli_version")"
  pinned_cli_version="$(current_cli_version)"

  restart_reason=""
  if [[ "$REFRESH" -eq 1 ]]; then
    restart_reason="stable artifacts were refreshed"
  elif [[ -n "$daemon_cli_path" && "$daemon_cli_path" != "$CLI_BIN" ]]; then
    restart_reason="existing daemon uses a different CLI path"
  elif [[ -n "$daemon_cli_path" && "$daemon_cli_path" == "$CLI_BIN" ]]; then
    if [[ -n "$daemon_cli_version" && -n "$pinned_cli_version" && "$daemon_cli_version" != "$pinned_cli_version" ]]; then
      restart_reason="existing daemon version does not match the pinned stable CLI"
    else
      return 0
    fi
  elif [[ -n "$daemon_cli_version" && -n "$pinned_cli_version" && "$daemon_cli_version" == "$pinned_cli_version" ]]; then
    return 0
  else
    restart_reason="existing daemon identity could not be verified"
  fi

  echo "Restarting default app-server so stable desktop can use the pinned CLI:"
  echo "  reason:  $restart_reason"
  echo "  pid:     $pid"
  if [[ -n "$daemon_cli_path" ]]; then
    echo "  current: $daemon_cli_path"
  elif [[ -n "$daemon_cli_version" ]]; then
    echo "  current: $daemon_cli_version"
  else
    echo "  current: <unknown>"
  fi
  echo "  target:  $CLI_BIN"
  if [[ -n "$daemon_cli_version" ]]; then
    echo "  current version: $daemon_cli_version"
  fi
  if [[ -n "$pinned_cli_version" ]]; then
    echo "  target version:  $pinned_cli_version"
  fi

  stop_pid_for_stable_restart "$pid"

  if [[ -f "$state_path" ]] && ! pid_is_alive "$pid"; then
    rm -f "$state_path"
  fi
}

needs_refresh() {
  [[ "$REFRESH" -eq 1 ]] && return 0
  [[ -x "$CLI_BIN" ]] || return 0
  [[ -x "$DESKTOP_BIN" ]] || return 0
  [[ -f "$MANIFEST_PATH" ]] || return 0
  return 1
}

git_value() {
  local cmd="$1"
  if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$ROOT_DIR" $cmd 2>/dev/null || true
  fi
}

write_manifest() {
  local commit dirty built_at
  commit="$(git_value 'rev-parse HEAD')"
  dirty="false"
  if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if ! git -C "$ROOT_DIR" diff --quiet --ignore-submodules=all; then
      dirty="true"
    fi
  fi
  built_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  cat > "$MANIFEST_PATH" <<EOF
{
  "build_mode": "$BUILD_MODE",
  "built_at": "$built_at",
  "git_commit": "$commit",
  "git_dirty": $dirty,
  "cli_path": "$CLI_BIN",
  "desktop_path": "$DESKTOP_BIN"
}
EOF
}

refresh_stable_artifacts() {
  if ! command -v go >/dev/null 2>&1; then
    echo "go is required to build the stable muxagent CLI binary" >&2
    exit 1
  fi
  if ! command -v pnpm >/dev/null 2>&1; then
    echo "pnpm is required to build the stable desktop binary" >&2
    exit 1
  fi

  mkdir -p "$BIN_DIR"

  local cli_target desktop_target
  cli_target="$CLI_BIN"
  desktop_target="$DESKTOP_BIN"

  echo "Refreshing pinned stable artifacts under $STABLE_ROOT"
  echo "  build mode: $BUILD_MODE"

  (
    cd "$CLI_DIR"
    go build -o "$cli_target" ./cmd/muxagent
  )

  (
    cd "$DESKTOP_DIR"
    if [[ "$BUILD_MODE" == "debug" ]]; then
      pnpm tauri build --debug
      cp "$DESKTOP_DIR/src-tauri/target/debug/muxagent-desktop" "$desktop_target"
    else
      pnpm tauri build
      cp "$DESKTOP_DIR/src-tauri/target/release/muxagent-desktop" "$desktop_target"
    fi
  )

  chmod +x "$cli_target" "$desktop_target"
  write_manifest

  echo "Pinned stable artifacts ready:"
  echo "  cli:     $cli_target"
  echo "  desktop: $desktop_target"
  echo "  manifest:$MANIFEST_PATH"
}

if needs_refresh; then
  refresh_stable_artifacts
fi

if [[ ! -x "$CLI_BIN" ]]; then
  echo "Missing pinned stable CLI: $CLI_BIN" >&2
  exit 1
fi

if [[ ! -x "$DESKTOP_BIN" ]]; then
  echo "Missing pinned stable desktop binary: $DESKTOP_BIN" >&2
  exit 1
fi

if [[ "$LAUNCH" -eq 0 ]]; then
  exit 0
fi

maybe_restart_default_app_server

echo "Launching pinned stable desktop with:"
echo "  cli:     $CLI_BIN"
echo "  desktop: $DESKTOP_BIN"
echo "  state:   $DEFAULT_MUXAGENT_ROOT"
if [[ -f "$MANIFEST_PATH" ]]; then
  echo "  manifest:$MANIFEST_PATH"
fi

if [[ ${#APP_ARGS[@]} -gt 0 ]]; then
  exec env \
    -u MUXAGENT_TASK_HOME \
    -u MUXAGENT_TASKCONFIG_ROOT \
    -u MUXAGENT_APP_SERVER_STATE_DIR \
    MUXAGENT_CLI_PATH="$CLI_BIN" \
    "$DESKTOP_BIN" "${APP_ARGS[@]}"
fi

exec env \
  -u MUXAGENT_TASK_HOME \
  -u MUXAGENT_TASKCONFIG_ROOT \
  -u MUXAGENT_APP_SERVER_STATE_DIR \
  MUXAGENT_CLI_PATH="$CLI_BIN" \
  "$DESKTOP_BIN"
