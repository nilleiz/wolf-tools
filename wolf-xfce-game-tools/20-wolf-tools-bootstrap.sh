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

config_dir="$HOME/.config/wolf-tools"
applications_dir="$HOME/.local/share/applications"

mkdir -p "$config_dir" "$applications_dir" "$HOME/bin"
chown -R 1000:1000 "$HOME/.config" "$HOME/.local" "$HOME/bin" || true

if [[ -f /usr/local/bin/wolf-tools-setup-ui.sh ]]; then
  install -m 0755 -o 1000 -g 1000 /usr/local/bin/wolf-tools-setup-ui.sh "$HOME/bin/wolf-tools-setup-ui"
fi

setup_needed="$config_dir/setup-needed"
setup_done="$config_dir/setup-done"

protontricks_app="com.github.Matoking.protontricks"
ludusavi_app="com.github.mtkennerly.ludusavi"

needs_setup=false
if command -v flatpak >/dev/null 2>&1; then
  if command -v su >/dev/null 2>&1; then
    if ! su -s /bin/bash "$USER" -c "XDG_DATA_HOME=\"$HOME/.local/share\" XDG_CONFIG_HOME=\"$HOME/.config\" flatpak --user info $protontricks_app >/dev/null 2>&1"; then
      needs_setup=true
    fi
    if ! su -s /bin/bash "$USER" -c "XDG_DATA_HOME=\"$HOME/.local/share\" XDG_CONFIG_HOME=\"$HOME/.config\" flatpak --user info $ludusavi_app >/dev/null 2>&1"; then
      needs_setup=true
    fi
  else
    needs_setup=true
  fi
else
  needs_setup=true
fi

if [[ "$needs_setup" == "true" ]]; then
  touch "$setup_needed"
  chown 1000:1000 "$setup_needed" || true
else
  rm -f "$setup_needed"
fi

if [[ -f "$setup_done" ]]; then
  chown 1000:1000 "$setup_done" || true
fi
