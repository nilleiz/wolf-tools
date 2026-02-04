#!/usr/bin/env bash
set -u
set -o pipefail
set -E

trap 'printf "[wolf-tools] bootstrap failed at line %s\n" "$LINENO" >&2' ERR

export HOME="${HOME:-/home/retro}"
export USER="${USER:-retro}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

config_dir="$XDG_CONFIG_HOME/wolf-tools"
mkdir -p "$config_dir"

log_file="$config_dir/bootstrap.log"
system_log="/var/log/wolf-tools-bootstrap.log"
log_targets=("$log_file")
if [[ -w "$system_log" ]] || touch "$system_log" >/dev/null 2>&1; then
  log_targets+=("$system_log")
fi
exec > >(tee -a "${log_targets[@]}") 2>&1

log() {
  printf '[wolf-tools] %s\n' "$*" >&2
}

run() {
  log "RUN: $*"
  "$@"
  local rc=$?
  log "RC=$rc"
  return $rc
}

set -x

pending_marker="$config_dir/bootstrap.pending"
done_marker="$config_dir/bootstrap.done"

log "bootstrap start"

if [[ -f "$done_marker" ]]; then
  log "bootstrap already completed; exiting"
  exit 0
fi

if [[ ! -f "$pending_marker" ]]; then
  log "bootstrap not pending; exiting"
  exit 0
fi

ui_tool=""
if command -v zenity >/dev/null 2>&1; then
  ui_tool="zenity"
elif command -v yad >/dev/null 2>&1; then
  ui_tool="yad"
elif command -v xmessage >/dev/null 2>&1; then
  ui_tool="xmessage"
fi

ui_pid=""
ui_fd=""

show_progress() {
  local message="$1"
  case "$ui_tool" in
    zenity)
      local ui_fifo
      ui_fifo="$(mktemp -u)"
      mkfifo "$ui_fifo"
      zenity --progress --pulsate --no-cancel --title="Wolf Tools" --text="$message" <"$ui_fifo" &
      ui_pid=$!
      exec {ui_fd}>"$ui_fifo"
      rm -f "$ui_fifo"
      ;;
    yad)
      local ui_fifo
      ui_fifo="$(mktemp -u)"
      mkfifo "$ui_fifo"
      yad --progress --pulsate --no-buttons --title="Wolf Tools" --text="$message" <"$ui_fifo" &
      ui_pid=$!
      exec {ui_fd}>"$ui_fifo"
      rm -f "$ui_fifo"
      ;;
    xmessage)
      xmessage -center "$message" &
      ui_pid=$!
      ;;
    *)
      ui_pid=""
      ;;
  esac
}

update_progress() {
  local message="$1"
  if [[ -n "$ui_fd" ]]; then
    printf 'text:%s\npulse\n' "$message" >&"$ui_fd"
  fi
}

close_progress() {
  if [[ -n "$ui_pid" ]]; then
    kill "$ui_pid" >/dev/null 2>&1 || true
  fi
  if [[ -n "$ui_fd" ]]; then
    exec {ui_fd}>&-
    ui_fd=""
  fi
}

show_info() {
  local message="$1"
  case "$ui_tool" in
    zenity)
      zenity --info --no-wrap --title="Wolf Tools" --text="$message"
      ;;
    yad)
      yad --info --title="Wolf Tools" --text="$message"
      ;;
    xmessage)
      xmessage -center "$message"
      ;;
    *)
      printf '%s\n' "$message"
      ;;
  esac
}

show_error() {
  local message="$1"
  case "$ui_tool" in
    zenity)
      zenity --error --no-wrap --title="Wolf Tools" --text="$message"
      ;;
    yad)
      yad --error --title="Wolf Tools" --text="$message"
      ;;
    xmessage)
      xmessage -center "$message"
      ;;
    *)
      printf '%s\n' "$message" >&2
      ;;
  esac
}

trap 'close_progress' EXIT

show_progress "Wolf Tools setup in progress…"
update_progress "Preparing directories…"

install_log="$config_dir/setup-install.log"
: >"$install_log"

mkdir -p "$XDG_DATA_HOME/applications" "$HOME/.local/bin" "$HOME/.local/share" "$HOME/ludusavi-backup"

steam_link="$HOME/.local/share/Steam"
if [[ -e "$steam_link" && ! -L "$steam_link" ]]; then
  rm -rf "$steam_link"
fi
ln -sfn "$HOME/.steam/debian-installation" "$steam_link"

protontricks_app="com.github.Matoking.protontricks"
ludusavi_app="com.github.mtkennerly.ludusavi"

update_progress "Ensuring Flathub remote…"

remote_names="$(run flatpak --user remotes --columns=name || true)"
if ! printf '%s\n' "$remote_names" | grep -qx "flathub"; then
  log "Flathub remote missing; attempting to add."
  if ! run flatpak --user remote-add flathub https://flathub.org/repo/flathub.flatpakrepo >>"$install_log" 2>&1; then
    log "Failed to add Flathub remote (continuing)."
  fi
fi

update_progress "Installing Flatpaks…"

if ! run flatpak --user info "$protontricks_app" >/dev/null 2>&1; then
  run flatpak --user install -y flathub "$protontricks_app" >>"$install_log" 2>&1 || true
fi

if ! run flatpak --user info "$ludusavi_app" >/dev/null 2>&1; then
  run flatpak --user install -y flathub "$ludusavi_app" >>"$install_log" 2>&1 || true
fi

update_progress "Verifying Flatpaks…"

install_ok=true
if ! run flatpak --user info "$protontricks_app" >>"$install_log" 2>&1; then
  log "Protontricks verification failed."
  install_ok=false
fi
if ! run flatpak --user info "$ludusavi_app" >>"$install_log" 2>&1; then
  log "Ludusavi verification failed."
  install_ok=false
fi

update_progress "Applying Flatpak permissions…"

override_paths=(
  "/mnt"
  "$HOME/.steam"
  "$HOME/.local/share/Steam"
)

for app in "$protontricks_app" "$ludusavi_app"; do
  for path in "${override_paths[@]}"; do
    run flatpak --user override --filesystem="$path" "$app" >>"$install_log" 2>&1 || true
  done
done

update_progress "Creating launchers…"

applications_dir="$XDG_DATA_HOME/applications"

cat <<'DESKTOP_ENTRY' > "$applications_dir/protontricks.desktop"
[Desktop Entry]
Type=Application
Name=Protontricks
Exec=sh -c 'flatpak run --env=GTK_USE_PORTAL=0 --env=GIO_USE_VFS=local --env=STEAM_DIR=/home/retro/.steam/debian-installation com.github.Matoking.protontricks ${PROTONTRICKS_NO_BWRAP:+--no-bwrap} --gui'
Icon=com.github.Matoking.protontricks
Categories=Game;
Terminal=false
DESKTOP_ENTRY

cat <<'DESKTOP_ENTRY' > "$applications_dir/ludusavi.desktop"
[Desktop Entry]
Type=Application
Name=Ludusavi
Exec=flatpak run --env=GTK_USE_PORTAL=0 com.github.mtkennerly.ludusavi
Icon=com.github.mtkennerly.ludusavi
Categories=Game;
Terminal=false
DESKTOP_ENTRY

cat <<'DESKTOP_ENTRY' > "$applications_dir/com.github.Matoking.protontricks.desktop"
[Desktop Entry]
Hidden=true
NoDisplay=true
DESKTOP_ENTRY

cat <<'DESKTOP_ENTRY' > "$applications_dir/com.github.mtkennerly.ludusavi.desktop"
[Desktop Entry]
Hidden=true
NoDisplay=true
DESKTOP_ENTRY

restart_needed=false

if ! update-desktop-database "$applications_dir" >/dev/null 2>&1; then
  restart_needed=true
fi

if ! xfce4-panel -r >/dev/null 2>&1; then
  restart_needed=true
  pkill xfce4-panel >/dev/null 2>&1 || true
  xfce4-panel >/dev/null 2>&1 &
fi

rm -f "$pending_marker"
touch "$done_marker"

close_progress

if [[ "$install_ok" != "true" ]]; then
  show_error "Setup completed with errors.\n\nCheck $install_log for details."
elif [[ "$restart_needed" == "true" ]]; then
  show_info "Setup complete.\n\nIf the menu still looks out of date, restart the container once."
else
  show_info "Setup complete.\n\nLudusavi backups can be placed in /home/retro/ludusavi-backup."
fi

log "bootstrap end"
