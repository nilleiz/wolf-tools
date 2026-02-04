#!/usr/bin/with-contenv bash
set -u
set -o pipefail
set -E

trap 'printf "[wolf-tools] bootstrap failed at line %s\n" "$LINENO" >&2' ERR

log() {
  printf '[wolf-tools] %s\n' "$*" >&2
}

log "bootstrap start"

if ! id -u "${USER:-retro}" >/dev/null 2>&1; then
  log "user ${USER:-retro} not available; exiting"
  exit 0
fi

export HOME="${HOME:-/home/retro}"
export USER="${USER:-retro}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1000}"

mkdir -p "$XDG_RUNTIME_DIR"
chown 1000:1000 "$XDG_RUNTIME_DIR" || true
chmod 700 "$XDG_RUNTIME_DIR" || true

config_dir="$HOME/.config/wolf-tools"
bootstrap_log="$config_dir/bootstrap.log"
system_log="/var/log/wolf-tools-bootstrap.log"
autostart_dir="$HOME/.config/autostart"
bin_dir="$HOME/.local/bin"

mkdir -p "$config_dir" "$autostart_dir" "$bin_dir" "$HOME/.local/share"
touch "$bootstrap_log" "$system_log"
chown 1000:1000 "$bootstrap_log" "$system_log" || true
chmod 0644 "$bootstrap_log" "$system_log" || true
chown -R 1000:1000 "$HOME/.config" "$HOME/.local" || true

exec > >(tee -a "$system_log") 2>&1

pending_marker="$config_dir/bootstrap.pending"
done_marker="$config_dir/bootstrap.done"

if [[ -f /usr/local/bin/wolf-tools-firstboot.sh ]]; then
  install -m 0755 -o 1000 -g 1000 /usr/local/bin/wolf-tools-firstboot.sh "$bin_dir/wolf-tools-firstboot"
fi

cat <<'DESKTOP_ENTRY' > "$autostart_dir/wolf-tools-firstboot.desktop"
[Desktop Entry]
Type=Application
Name=Wolf Tools First Boot
Exec=/home/retro/.local/bin/wolf-tools-firstboot
OnlyShowIn=XFCE;
Terminal=false
X-GNOME-Autostart-enabled=true
Hidden=false
DESKTOP_ENTRY
chown 1000:1000 "$autostart_dir/wolf-tools-firstboot.desktop" || true
chmod 0644 "$autostart_dir/wolf-tools-firstboot.desktop" || true

if [[ -f "$done_marker" ]]; then
  rm -f "$pending_marker"
else
  touch "$pending_marker"
  chown 1000:1000 "$pending_marker" || true
fi

log "bootstrap end"
