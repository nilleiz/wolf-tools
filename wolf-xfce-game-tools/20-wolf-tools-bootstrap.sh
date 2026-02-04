#!/usr/bin/with-contenv bash
set -u
set -o pipefail

trap 'echo "[wolf-tools] bootstrap failed at line $LINENO"' ERR

echo "[wolf-tools] bootstrap start"

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
bootstrap_log="$config_dir/bootstrap.log"
system_log="/var/log/wolf-tools-bootstrap.log"
applications_dir="$HOME/.local/share/applications"
autostart_dir="$HOME/.config/autostart"
local_bin_dir="$HOME/.local/bin"
pending_file="$config_dir/bootstrap.pending"
done_file="$config_dir/bootstrap.done"

mkdir -p "$config_dir" "$applications_dir" "$HOME/bin" "$autostart_dir" "$local_bin_dir"
touch "$bootstrap_log" "$system_log"
chown 1000:1000 "$bootstrap_log" "$system_log" || true
chmod 0644 "$bootstrap_log" "$system_log" || true
chown -R 1000:1000 "$HOME/.config" "$HOME/.local" "$HOME/bin" || true

if [[ -f /usr/local/bin/wolf-tools-firstboot.sh ]]; then
  install -m 0755 -o 1000 -g 1000 /usr/local/bin/wolf-tools-firstboot.sh "$local_bin_dir/wolf-tools-firstboot"
fi

cat <<'EOF' >"$autostart_dir/wolf-tools-firstboot.desktop"
[Desktop Entry]
Type=Application
Name=Wolf Tools First Boot
Exec=/home/retro/.local/bin/wolf-tools-firstboot
OnlyShowIn=XFCE;
Terminal=false
X-GNOME-Autostart-enabled=true
Hidden=false
EOF
chown 1000:1000 "$autostart_dir/wolf-tools-firstboot.desktop" || true
chmod 0644 "$autostart_dir/wolf-tools-firstboot.desktop" || true

if [[ -f "$done_file" ]]; then
  rm -f "$pending_file"
else
  touch "$pending_file"
  chown 1000:1000 "$pending_file" || true
fi

echo "[wolf-tools] Prepared firstboot script and autostart entry."

echo "[wolf-tools] bootstrap end"
