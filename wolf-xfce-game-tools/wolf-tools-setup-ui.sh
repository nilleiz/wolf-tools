#!/usr/bin/env bash
set -u

export HOME="${HOME:-/home/retro}"
export USER="${USER:-retro}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

config_dir="$XDG_CONFIG_HOME/wolf-tools"
mkdir -p "$config_dir"

log_file="$config_dir/setup-ui.log"
exec >>"$log_file" 2>&1

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

show_progress() {
  local message="$1"
  case "$ui_tool" in
    zenity)
      zenity --progress --pulsate --no-cancel --title="Wolf Tools" --text="$message" &
      ui_pid=$!
      ;;
    yad)
      yad --progress --pulsate --no-buttons --title="Wolf Tools" --text="$message" &
      ui_pid=$!
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

close_progress() {
  if [[ -n "$ui_pid" ]]; then
    kill "$ui_pid" >/dev/null 2>&1 || true
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

install_log="$config_dir/setup-install.log"
: >"$install_log"

protontricks_app="com.github.Matoking.protontricks"
ludusavi_app="com.github.mtkennerly.ludusavi"

log "Ensuring Flathub remote exists."
if ! flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >>"$install_log" 2>&1; then
  close_progress
  show_error "Failed to add Flathub remote.\n\n$(cat "$install_log")"
  exit 0
fi

log "Installing flatpaks."
if ! flatpak --user install -y flathub "$protontricks_app" "$ludusavi_app" >>"$install_log" 2>&1; then
  close_progress
  show_error "Failed to install Protontricks or Ludusavi.\n\n$(cat "$install_log")"
  exit 0
fi

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

log "Creating wrappers and desktop entries."

bin_dir="$HOME/bin"
mkdir -p "$bin_dir"

protontricks_gui="$bin_dir/protontricks-gui"
cat <<'PROTONTRICKS_GUI' > "$protontricks_gui"
#!/usr/bin/env bash
set -euo pipefail

steam_dir=""
if [[ -d "$HOME/.steam/debian-installation" ]]; then
  steam_dir="$HOME/.steam/debian-installation"
elif [[ -d "$HOME/.steam/steam" ]]; then
  steam_dir="$HOME/.steam/steam"
elif [[ -d "$HOME/.local/share/Steam" ]]; then
  steam_dir="$HOME/.local/share/Steam"
fi

if [[ -n "$steam_dir" ]]; then
  export STEAM_DIR="$steam_dir"
fi
export GTK_USE_PORTAL=0

exec flatpak run com.github.Matoking.protontricks --no-bwrap --gui "$@"
PROTONTRICKS_GUI
chmod 0755 "$protontricks_gui"

ludusavi_wrapper="$bin_dir/ludusavi"
cat <<'LUDUSAVI_WRAPPER' > "$ludusavi_wrapper"
#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[ludusavi] %s\n' "$*" >&2
}

STEAM_ROOT=""
steam_candidates=(
  "$HOME/.steam/debian-installation"
  "$HOME/.local/share/Steam"
  "$HOME/.steam/steam"
)

for candidate in "${steam_candidates[@]}"; do
  if [[ -f "$candidate/steamapps/libraryfolders.vdf" ]]; then
    STEAM_ROOT="$candidate"
    break
  fi
done

canonical_steam="$HOME/.local/share/Steam"
if [[ -n "$STEAM_ROOT" ]]; then
  mkdir -p "$HOME/.local/share" 2>/dev/null || true
  if ln -sfn "$STEAM_ROOT" "$canonical_steam" 2>/dev/null; then
    log "Ensured Steam symlink at $canonical_steam -> $STEAM_ROOT"
  else
    log "Unable to create Steam symlink at $canonical_steam"
  fi
fi
library_paths=()
library_file=""
if [[ -n "$STEAM_ROOT" ]]; then
  library_file="$STEAM_ROOT/steamapps/libraryfolders.vdf"
fi
if [[ -n "$library_file" && -f "$library_file" ]]; then
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    if [[ -d "$path" ]]; then
      library_paths+=("$path")
    fi
  done < <(
    grep -E '"path"' "$library_file" | \
      sed -E 's/.*"path"[[:space:]]*"([^"]+)".*/\1/' | \
      sed 's#\\\\#/#g' | \
      sort -u
  )
fi

declare -A ludusavi_paths=()
add_path() {
  local path="$1"
  [[ -n "$path" ]] || return
  ludusavi_paths["$path"]=1
}

if [[ -n "$STEAM_ROOT" ]]; then
  add_path "$STEAM_ROOT/steamapps"
  add_path "$STEAM_ROOT/steamapps/compatdata"
fi

for lp in "${library_paths[@]}"; do
  add_path "$lp/steamapps"
  add_path "$lp/steamapps/compatdata"
done

if [[ -d "$canonical_steam" ]]; then
  add_path "$canonical_steam"
fi

sorted_paths=()
if [[ ${#ludusavi_paths[@]} -gt 0 ]]; then
  mapfile -t sorted_paths < <(printf '%s\n' "${!ludusavi_paths[@]}" | sort -u)
fi

if command -v flatpak >/dev/null 2>&1; then
  flatpak --user override --reset com.github.mtkennerly.ludusavi || true
  if [[ ${#sorted_paths[@]} -gt 0 ]]; then
    log "Applying scoped overrides: ${sorted_paths[*]}"
    for path in "${sorted_paths[@]}"; do
      flatpak --user override --filesystem="$path" com.github.mtkennerly.ludusavi || true
    done
  else
    log "No Steam paths detected to scope Ludusavi."
  fi
else
  log "Flatpak not available; skipping overrides."
fi

exec flatpak run com.github.mtkennerly.ludusavi
LUDUSAVI_WRAPPER
chmod 0755 "$ludusavi_wrapper"

applications_dir="$XDG_DATA_HOME/applications"
mkdir -p "$applications_dir"

rm -f \
  "$applications_dir/protontricks-gui.desktop" \
  "$applications_dir/protontricks-container-safe.desktop" \
  "$applications_dir/ludusavi-steam.desktop" \
  "$applications_dir/ludusavi-container-safe.desktop"

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
  show_info "Setup complete. Please restart the container once."
else
  show_info "Setup complete."
fi

exit 0
