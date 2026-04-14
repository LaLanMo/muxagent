#!/usr/bin/env sh
set -eu

REPO="${MUXAGENT_REPO:-LaLanMo/muxagent}"
INSTALLER_URL="${MUXAGENT_INSTALLER_URL:-https://raw.githubusercontent.com/$REPO/main/cli/install.sh}"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

need_cmd curl
need_cmd mktemp
need_cmd chmod

tmp_installer="$(mktemp)"
cleanup() {
  rm -f "$tmp_installer"
}
trap cleanup EXIT INT TERM

curl -fsSL --retry 3 --connect-timeout 15 "$INSTALLER_URL" -o "$tmp_installer"
chmod 755 "$tmp_installer"
exec /bin/sh "$tmp_installer" "$@"
