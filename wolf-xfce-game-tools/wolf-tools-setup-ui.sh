#!/usr/bin/env bash
set -u

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

setup_needed="$config_dir/setup-needed"
setup_done="$config_dir/setup-done"

if [[ -f "$setup_done" ]]; then
  exit 0
fi

if [[ ! -f "$setup_needed" ]]; then
  exit 0
fi

log() {
  printf '%s %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*"
}

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

show_progress "Setting up Protontricks and Ludusavi…"
update_progress "Preparing user directories…"

install_log="$config_dir/setup-install.log"
: >"$install_log"

protontricks_app="com.github.Matoking.protontricks"
ludusavi_app="com.github.mtkennerly.ludusavi"
override_paths=(
  "/mnt"
  "$HOME/.steam"
  "$HOME/.local/share/Steam"
)

mkdir -p "$HOME/.local/share" "$HOME/ludusavi-backup"
steam_link="$HOME/.local/share/Steam"
if [[ -e "$steam_link" && ! -L "$steam_link" ]]; then
  rm -rf "$steam_link"
fi
ln -sfn "$HOME/.steam/debian-installation" "$steam_link"

update_progress "Ensuring Flatpak remote…"

log "Ensuring Flathub remote exists."
flatpak_ready=false
for i in {1..10}; do
  if flatpak --user remotes >/dev/null 2>&1; then
    flatpak_ready=true
    break
  fi
  sleep 1
done
if [[ "$flatpak_ready" != "true" ]]; then
  close_progress
  show_error "Flatpak is not ready yet. Please restart the container and try again."
  exit 0
fi
if ! flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >>"$install_log" 2>&1; then
  close_progress
  show_error "Failed to add Flathub remote.\n\n$(cat "$install_log")"
  exit 0
fi

update_progress "Installing Flatpaks…"
log "Installing flatpaks if missing."
for app in "$protontricks_app" "$ludusavi_app"; do
  if ! flatpak --user info "$app" >/dev/null 2>&1; then
    if ! flatpak --user install -y flathub "$app" >>"$install_log" 2>&1; then
      close_progress
      show_error "Failed to install $app.\n\n$(cat "$install_log")"
      exit 0
    fi
  fi
done

update_progress "Verifying Flatpaks…"
log "Verifying flatpaks."
if ! flatpak info "$protontricks_app" >>"$install_log" 2>&1; then
  close_progress
  show_error "Protontricks verification failed.\n\n$(cat "$install_log")"
  exit 0
fi
if ! flatpak info "$ludusavi_app" >>"$install_log" 2>&1; then
  close_progress
  show_error "Ludusavi verification failed.\n\n$(cat "$install_log")"
  exit 0
fi

update_progress "Applying Flatpak permissions…"
log "Applying flatpak overrides."
for app in "$protontricks_app" "$ludusavi_app"; do
  for path in "${override_paths[@]}"; do
    flatpak --user override --filesystem="$path" "$app" >>"$install_log" 2>&1 || true
  done
done

update_progress "Creating launchers…"
log "Creating wrappers and desktop entries."

bin_dir="$HOME/bin"
mkdir -p "$bin_dir"

protontricks_gui="$bin_dir/protontricks-gui"
cat <<'PROTONTRICKS_GUI' > "$protontricks_gui"
#!/usr/bin/env bash
set -euo pipefail

export GTK_USE_PORTAL=0
export GIO_USE_VFS=local

exec flatpak run \
  --env=STEAM_DIR=/home/retro/.steam/debian-installation \
  --env=GTK_USE_PORTAL=0 \
  --env=GIO_USE_VFS=local \
  com.github.Matoking.protontricks --gui "$@"
PROTONTRICKS_GUI
chmod 0755 "$protontricks_gui"

ludusavi_wrapper="$bin_dir/ludusavi"
cat <<'LUDUSAVI_WRAPPER' > "$ludusavi_wrapper"
#!/usr/bin/env bash
set -euo pipefail

export GTK_USE_PORTAL=0
export GIO_USE_VFS=local

exec flatpak run \
  --env=GTK_USE_PORTAL=0 \
  --env=GIO_USE_VFS=local \
  com.github.mtkennerly.ludusavi "$@"
LUDUSAVI_WRAPPER
chmod 0755 "$ludusavi_wrapper"

applications_dir="$XDG_DATA_HOME/applications"
mkdir -p "$applications_dir"

update_progress "Removing duplicate menu entries…"
rm -f "$applications_dir/"*protontricks*.desktop "$applications_dir/"*ludusavi*.desktop
desktop_sources=(
  "$HOME/.local/share/flatpak/exports/share/applications"
  "/var/lib/flatpak/exports/share/applications"
  "/usr/share/applications"
  "/usr/local/share/applications"
  "/app/share/applications"
)
for source_dir in "${desktop_sources[@]}"; do
  [[ -d "$source_dir" ]] || continue
  while IFS= read -r desktop_file; do
    desktop_name="$(basename "$desktop_file")"
    case "$desktop_name" in
      com.github.Matoking.protontricks.desktop|com.github.mtkennerly.ludusavi.desktop)
        continue
        ;;
    esac
    cat <<'DESKTOP_ENTRY' > "$applications_dir/$desktop_name"
[Desktop Entry]
Hidden=true
NoDisplay=true
DESKTOP_ENTRY
  done < <(find "$source_dir" -maxdepth 1 -type f \( -iname '*protontricks*.desktop' -o -iname '*ludusavi*.desktop' \))
done

cat <<'DESKTOP_ENTRY' > "$applications_dir/com.github.Matoking.protontricks.desktop"
[Desktop Entry]
Type=Application
Name=Protontricks
Exec=/home/retro/bin/protontricks-gui
Icon=com.github.Matoking.protontricks
Categories=Game;
Terminal=false
DESKTOP_ENTRY

cat <<'DESKTOP_ENTRY' > "$applications_dir/com.github.mtkennerly.ludusavi.desktop"
[Desktop Entry]
Type=Application
Name=Ludusavi
Exec=/home/retro/bin/ludusavi
Icon=com.github.mtkennerly.ludusavi
Categories=Game;
Terminal=false
DESKTOP_ENTRY

env_dir="$XDG_CONFIG_HOME/environment.d"
mkdir -p "$env_dir"
cat <<ENV_FILE > "$env_dir/10-wolf-tools.conf"
PATH=$HOME/bin:$PATH
ENV_FILE

restart_needed=false

if ! update-desktop-database "$applications_dir" >/dev/null 2>&1; then
  restart_needed=true
fi

if ! xfce4-panel --restart >/dev/null 2>&1; then
  restart_needed=true
fi

if ! xfdesktop --reload >/dev/null 2>&1; then
  restart_needed=true
fi

if ! flatpak run --command=true "$ludusavi_app" >/dev/null 2>&1; then
  restart_needed=true
fi

if ! flatpak run --command=true "$protontricks_app" >/dev/null 2>&1; then
  restart_needed=true
fi

rm -f "$setup_needed"
touch "$setup_done"

close_progress

if [[ "$restart_needed" == "true" ]]; then
  show_info "Setup complete.\n\nIf you still see missing icons, restart the container once.\n\nLudusavi backups can be placed in /home/retro/ludusavi-backup."
else
  show_info "Setup complete.\n\nLudusavi backups can be placed in /home/retro/ludusavi-backup."
fi

exit 0
