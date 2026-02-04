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

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [[ ! -d "$XDG_RUNTIME_DIR" ]]; then
  mkdir -p "$XDG_RUNTIME_DIR"
fi

dbus_session_ready() {
  if command -v dbus-send >/dev/null 2>&1; then
    dbus-send --session --dest=org.freedesktop.DBus --type=method_call / org.freedesktop.DBus.ListNames >/dev/null 2>&1
    return $?
  fi
  if command -v gdbus >/dev/null 2>&1; then
    gdbus call --session --dest org.freedesktop.DBus --object-path / --method org.freedesktop.DBus.ListNames >/dev/null 2>&1
    return $?
  fi
  log "No dbus-send or gdbus available to verify DBus readiness."
  return 0
}

display_ready() {
  if command -v xdpyinfo >/dev/null 2>&1; then
    xdpyinfo >/dev/null 2>&1
    return $?
  fi
  log "xdpyinfo not available; skipping X11 probe."
  return 0
}

wait_for_session_ready() {
  if [[ -z "${DISPLAY:-}" ]]; then
    export DISPLAY=":0"
  fi

  log "Waiting for X11 session on DISPLAY=$DISPLAY"
  for _ in {1..60}; do
    if display_ready; then
      break
    fi
    sleep 1
  done

  log "Waiting for DBus session"
  for _ in {1..60}; do
    if dbus_session_ready; then
      return 0
    fi
    sleep 1
  done

  log "DBus session not ready after timeout"
  return 1
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
progress_fd=""
progress_fifo=""
start_progress() {
  if command -v zenity >/dev/null 2>&1; then
    progress_fifo="$(mktemp -u "${XDG_RUNTIME_DIR:-/tmp}/wolf-tools-progress.XXXX")"
    if mkfifo "$progress_fifo"; then
      zenity --progress --pulsate --no-cancel --auto-close \
        --title="Wolf Tools" \
        --text="Setting up Protontricks + Ludusavi…" <"$progress_fifo" &
      progress_pid=$!
      if exec {progress_fd}>"$progress_fifo"; then
        echo "# Setting up Protontricks + Ludusavi…" >&"$progress_fd" || true
      else
        log "Failed to open progress fifo; continuing without UI."
      fi
    else
      log "Failed to create progress fifo; continuing without UI."
    fi
  else
    log "Zenity not available; continuing without UI."
  fi
}

progress_update() {
  if [[ -n "$progress_fd" ]]; then
    echo "# $*" >&"$progress_fd" || true
  fi
}

stop_progress() {
  if [[ -n "$progress_fd" ]]; then
    exec {progress_fd}>&-
  fi
  if [[ -n "$progress_pid" ]]; then
    kill "$progress_pid" 2>/dev/null || true
    wait "$progress_pid" 2>/dev/null || true
  fi
  if [[ -n "$progress_fifo" ]]; then
    rm -f "$progress_fifo"
  fi
}

trap 'stop_progress' EXIT
wait_for_session_ready || true
start_progress

degraded=false

log "Ensuring Flathub remote exists."
progress_update "Adding Flathub…"
flatpak_remotes="$(run_capture flatpak remotes --user --columns=name 2>/dev/null || true)"
if [[ -z "$flatpak_remotes" ]]; then
  flatpak_remotes="$(run_capture flatpak remotes --user 2>/dev/null | awk 'NR>0 {print $1}' || true)"
fi
if ! grep -qx "flathub" <<<"$flatpak_remotes"; then
  if ! run flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo; then
    log "Failed to add Flathub remote (continuing in degraded mode)."
    degraded=true
  fi
fi

protontricks_app="com.github.Matoking.protontricks"
ludusavi_app="com.github.mtkennerly.ludusavi"

for app in "$protontricks_app" "$ludusavi_app"; do
  if [[ "$app" == "$protontricks_app" ]]; then
    progress_update "Installing Protontricks…"
  else
    progress_update "Installing Ludusavi…"
  fi
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

progress_update "Applying sandbox permissions…"
run flatpak override --user --filesystem=/mnt --filesystem=home --filesystem="$HOME/.steam" --filesystem="$HOME/.local/share/Steam" "$protontricks_app" || degraded=true
run flatpak override --user --filesystem=/mnt --filesystem=home --filesystem="$HOME/.steam" --filesystem="$HOME/.local/share/Steam" "$ludusavi_app" || degraded=true

run mkdir -p "$HOME/.local/share"
run ln -sfn "$HOME/.steam/debian-installation" "$HOME/.local/share/Steam"

applications_dir="$HOME/.local/share/applications"
run mkdir -p "$applications_dir"

progress_update "Creating menu shortcuts…"
cat <<'DESKTOP' >"$applications_dir/protontricks.desktop"
[Desktop Entry]
Type=Application
Name=Protontricks
Exec=/usr/bin/env bash -lc 'flatpak run --no-document-portal --env=GTK_USE_PORTAL=0 --env=GIO_USE_VFS=local --env=GDK_BACKEND=x11 --env=STEAM_DIR=$HOME/.steam/debian-installation com.github.Matoking.protontricks --gui'
Icon=com.github.Matoking.protontricks
Terminal=false
Categories=Game;Utility;
DESKTOP

cat <<'DESKTOP' >"$applications_dir/ludusavi.desktop"
[Desktop Entry]
Type=Application
Name=Ludusavi
Exec=/usr/bin/env bash -lc 'flatpak run --no-document-portal --env=GTK_USE_PORTAL=0 --env=GIO_USE_VFS=local --env=GDK_BACKEND=x11 com.github.mtkennerly.ludusavi'
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
sleep 2
xfce4-panel -r || true

autostart_entry="$HOME/.config/autostart/wolf-tools-firstboot.desktop"
if [[ -f "$autostart_entry" ]]; then
  if grep -q '^Hidden=' "$autostart_entry"; then
    sed -i 's/^Hidden=.*/Hidden=true/' "$autostart_entry"
  else
    echo 'Hidden=true' >>"$autostart_entry"
  fi
fi

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
