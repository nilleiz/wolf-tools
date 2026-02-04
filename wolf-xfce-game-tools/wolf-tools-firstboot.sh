#!/usr/bin/env bash
set -u
set -o pipefail
set -x

trap 'echo "[wolf-tools] bootstrap failed at line $LINENO"' ERR

log_dir="$HOME/.config/wolf-tools"
mkdir -p "$log_dir"
log_file="$log_dir/firstboot.log"
exec >>"$log_file" 2>&1

echo "[wolf-tools] firstboot start"

pending_file="$log_dir/bootstrap.pending"
done_file="$log_dir/bootstrap.done"
degraded_file="$log_dir/bootstrap.degraded"

if [[ ! -f "$pending_file" ]]; then
  echo "[wolf-tools] No pending bootstrap marker found; exiting."
  exit 0
fi

log() {
  echo "[wolf-tools] $*"
}

run() {
  log "RUN: $*"
  "$@"
  local rc=$?
  log "RC=$rc"
  return $rc
}

run_capture() {
  log "RUN: $*"
  local output
  output=$("$@")
  local rc=$?
  log "RC=$rc"
  printf '%s' "$output"
  return $rc
}

progress_pid=""
start_progress() {
  if command -v zenity >/dev/null 2>&1; then
    (
      while true; do
        echo "# Wolf Tools setup in progress…"
        sleep 2
      done
    ) | zenity --progress --pulsate --no-cancel --auto-close --title="Wolf Tools" --text="Wolf Tools setup in progress…" &
    progress_pid=$!
  fi
}

stop_progress() {
  if [[ -n "$progress_pid" ]]; then
    kill "$progress_pid" 2>/dev/null || true
    wait "$progress_pid" 2>/dev/null || true
  fi
}

trap 'stop_progress' EXIT
start_progress

degraded=false

log "Ensuring Flathub remote exists."
flatpak_remotes="$(run_capture flatpak --user remotes --columns=name 2>/dev/null || true)"
if ! grep -qx "flathub" <<<"$flatpak_remotes"; then
  if ! run flatpak --user remote-add flathub https://flathub.org/repo/flathub.flatpakrepo; then
    log "Failed to add Flathub remote (continuing in degraded mode)."
    degraded=true
  fi
fi

protontricks_app="com.github.Matoking.protontricks"
ludusavi_app="com.github.mtkennerly.ludusavi"

for app in "$protontricks_app" "$ludusavi_app"; do
  if ! run flatpak --user info "$app"; then
    log "Installing $app"
    if ! run flatpak --user install -y flathub "$app"; then
      log "Install failed for $app (continuing)."
      degraded=true
    fi
  else
    log "$app already installed"
  fi
done

run mkdir -p "$HOME/.local/share"
run ln -sfn "$HOME/.steam/debian-installation" "$HOME/.local/share/Steam"

applications_dir="$HOME/.local/share/applications"
run mkdir -p "$applications_dir"

cat <<'DESKTOP' >"$applications_dir/protontricks.desktop"
[Desktop Entry]
Type=Application
Name=Protontricks
Exec=flatpak run --env=GTK_USE_PORTAL=0 --env=GIO_USE_VFS=local --env=STEAM_DIR=/home/retro/.steam/debian-installation com.github.Matoking.protontricks --gui
Icon=com.github.Matoking.protontricks
Terminal=false
Categories=Game;Utility;
DESKTOP

cat <<'DESKTOP' >"$applications_dir/ludusavi.desktop"
[Desktop Entry]
Type=Application
Name=Ludusavi
Exec=flatpak run --env=GTK_USE_PORTAL=0 com.github.mtkennerly.ludusavi
Icon=com.github.mtkennerly.ludusavi
Terminal=false
Categories=Game;Utility;
DESKTOP

cat <<'DESKTOP' >"$applications_dir/com.github.Matoking.protontricks.desktop"
[Desktop Entry]
Hidden=true
DESKTOP

cat <<'DESKTOP' >"$applications_dir/com.github.mtkennerly.ludusavi.desktop"
[Desktop Entry]
Hidden=true
DESKTOP

update-desktop-database "$applications_dir" || true
xfce4-panel -r || true

rm -f "$pending_file"
touch "$done_file"
if [[ "$degraded" == "true" ]]; then
  touch "$degraded_file"
fi

stop_progress
if command -v zenity >/dev/null 2>&1; then
  zenity --info --title="Wolf Tools" --text="Setup complete"
fi

echo "[wolf-tools] firstboot end"
