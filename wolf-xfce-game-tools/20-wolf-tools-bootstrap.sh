#!/usr/bin/with-contenv bash
set -euo pipefail

if ! id -u "${USER:-retro}" >/dev/null 2>&1; then
  exit 0
fi

export HOME="${HOME:-/home/retro}"
export USER="${USER:-retro}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1000}"

mkdir -p "$XDG_RUNTIME_DIR"
chown 1000:1000 "$XDG_RUNTIME_DIR" || true
chmod 700 "$XDG_RUNTIME_DIR" || true

if command -v su >/dev/null 2>&1; then
  su -s /bin/bash "$USER" -c "/usr/local/bin/wolf-tools-bootstrap.sh"
else
  /usr/local/bin/wolf-tools-bootstrap.sh
fi
