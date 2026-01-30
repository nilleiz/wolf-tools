#!/usr/bin/env bash
set -u

LOG_DIR="$HOME/.config/wolf-tools"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/bootstrap.log"
exec >>"$LOG_FILE" 2>&1

echo "=== wolf-tools bootstrap start $(date -Is) ==="
echo "USER=$(id -un 2>/dev/null || echo unknown) UID=$(id -u 2>/dev/null || echo unknown) HOME=$HOME"
touch "$LOG_DIR/last-run"
date -Is > "$LOG_DIR/last-run"

log() {
  printf '%s %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*"
}

run_cmd() {
  if ! "$@"; then
    log "Command failed (ignored): $*"
  fi
}

retry_cmd() {
  local attempts="$1"
  shift
  local i
  for i in $(seq 1 "$attempts"); do
    if "$@"; then
      return 0
    fi
    log "Command failed (attempt $i/$attempts): $*"
    sleep 2
  done
  return 1
}

trap 'status=$?; if [[ $status -ne 0 ]]; then log "Bootstrap exited with status $status (ignored)."; fi; exit 0' EXIT

log "Starting Wolf tools bootstrap."
log "User: $(id -un 2>/dev/null || echo unknown) (uid=$(id -u 2>/dev/null || echo unknown) gid=$(id -g 2>/dev/null || echo unknown))"
log "id: $(id 2>/dev/null || echo unavailable)"
log "passwd entry for retro: $(getent passwd retro 2>/dev/null || echo missing)"
log "passwd entry for uid 1000: $(getent passwd 1000 2>/dev/null || echo missing)"
log "Environment:"
while IFS= read -r line; do
  log "env: $line"
done < <(env | sort)

sleep 2

if command -v flatpak >/dev/null 2>&1; then
  log "flatpak detected: $(command -v flatpak)"
  log "flatpak version: $(flatpak --version 2>/dev/null || echo unavailable)"
else
  log "flatpak missing"
fi

flatpak_ready=false
if command -v flatpak >/dev/null 2>&1; then
  for i in $(seq 1 15); do
    if flatpak --user remotes >/dev/null 2>&1; then
      flatpak_ready=true
      break
    fi
    log "Waiting for flatpak user session ($i/15)"
    sleep 1
  done
fi

if [[ "$flatpak_ready" == "true" ]]; then
  log "Flatpak user remotes:"
  flatpak --user remotes || log "Failed to list flatpak remotes"
  log "Ensuring Flathub remote exists"
  run_cmd flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

apps=(
  com.github.Matoking.protontricks
  com.github.mtkennerly.ludusavi
)

if [[ "$flatpak_ready" == "true" ]]; then
  for app in "${apps[@]}"; do
    if ! flatpak info --user "$app" >/dev/null 2>&1; then
      log "Installing $app"
      if ! retry_cmd 3 flatpak --user install -y flathub "$app"; then
        log "Install failed after retries: $app"
      fi
    else
      log "$app already installed"
    fi
  done
  log "Flatpak user list:"
  flatpak --user list || log "Failed to list installed Flatpaks"
  log "Protontricks version: $(flatpak run com.github.Matoking.protontricks --version 2>/dev/null || echo unavailable)"
else
  log "Skipping Flatpak install steps because flatpak user session is not ready."
fi

STEAM_ROOT=""
steam_candidates=(
  "$HOME/.steam/debian-installation"
  "$HOME/.local/share/Steam"
  "$HOME/.steam/steam"
)

for candidate in "${steam_candidates[@]}"; do
  if [[ -d "$candidate/steamapps" ]]; then
    STEAM_ROOT="$candidate"
    break
  fi
done

if [[ -z "$STEAM_ROOT" && -d "$HOME/.steam" ]]; then
  steamapps_path="$(find "$HOME/.steam" -maxdepth 4 -type d -name steamapps 2>/dev/null | head -n 1 || true)"
  if [[ -n "$steamapps_path" ]]; then
    STEAM_ROOT="$(dirname "$steamapps_path")"
  fi
fi

if [[ -z "$STEAM_ROOT" ]]; then
  log "Steam not detected yet; start Steam once and restart XFCE to apply overrides."
else
  log "Detected Steam root: $STEAM_ROOT"

  canonical_steam="$HOME/.local/share/Steam"
  if [[ "$STEAM_ROOT" == "$canonical_steam" ]]; then
    mkdir -p "$canonical_steam"
  else
    if [[ -e "$canonical_steam" && ! -L "$canonical_steam" ]]; then
      backup_path="${canonical_steam}.backup.$(date +'%Y%m%d%H%M%S')"
      log "Moving existing Steam directory to $backup_path"
      run_cmd mv "$canonical_steam" "$backup_path"
    fi
    if [[ -L "$canonical_steam" ]]; then
      current_target="$(readlink "$canonical_steam")"
      if [[ "$current_target" != "$STEAM_ROOT" ]]; then
        log "Updating Steam symlink from $current_target to $STEAM_ROOT"
        run_cmd rm "$canonical_steam"
        run_cmd ln -s "$STEAM_ROOT" "$canonical_steam"
      fi
    elif [[ ! -e "$canonical_steam" ]]; then
      log "Creating Steam symlink at $canonical_steam -> $STEAM_ROOT"
      run_cmd ln -s "$STEAM_ROOT" "$canonical_steam"
    fi
  fi
fi

mount_points=()
if [[ -r /proc/self/mountinfo ]]; then
  mapfile -t mount_points < <(
    awk '
      function excluded(fs) {
        return fs == "proc" || fs == "sysfs" || fs == "devtmpfs" || fs == "tmpfs" ||
               fs == "cgroup" || fs == "cgroup2" || fs == "overlay" || fs == "squashfs"
      }
      {
        split($0, parts, " - ")
        if (length(parts) < 2) next
        mp = $5
        split(parts[2], post, " ")
        fstype = post[1]
        if (index(mp, "/mnt/") == 1 && mp != "/mnt" && !excluded(fstype)) print mp
      }
    ' /proc/self/mountinfo | sort -u
  )
elif [[ -r /proc/mounts ]]; then
  mapfile -t mount_points < <(
    awk '
      function excluded(fs) {
        return fs == "proc" || fs == "sysfs" || fs == "devtmpfs" || fs == "tmpfs" ||
               fs == "cgroup" || fs == "cgroup2" || fs == "overlay" || fs == "squashfs"
      }
      {
        mp = $2
        fstype = $3
        if (index(mp, "/mnt/") == 1 && mp != "/mnt" && !excluded(fstype)) print mp
      }
    ' /proc/mounts | sort -u
  )
fi

if [[ ${#mount_points[@]} -gt 0 ]]; then
  log "Discovered /mnt mountpoints: ${mount_points[*]}"
else
  log "No /mnt mountpoints discovered"
fi

canonical_steam="$HOME/.local/share/Steam"
library_paths=()
library_file="$canonical_steam/steamapps/libraryfolders.vdf"
if [[ -f "$library_file" ]]; then
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    library_paths+=("$path")
  done < <(
    grep -E '"path"' "$library_file" | \
      sed -E 's/.*"path"[[:space:]]*"([^"]+)".*/\1/' | \
      sed 's#\\\\#/#g' | \
      sort -u
  )
  if [[ ${#library_paths[@]} -gt 0 ]]; then
    log "Discovered Steam library paths: ${library_paths[*]}"
  fi
else
  log "Steam library list not found yet at $library_file"
fi

declare -A filesystem_paths=()
add_path() {
  local path="$1"
  [[ -n "$path" ]] || return
  filesystem_paths["$path"]=1
}

if [[ -n "$STEAM_ROOT" ]]; then
  canonical_steam="$HOME/.local/share/Steam"
  add_path "$STEAM_ROOT"
  add_path "$canonical_steam"
fi
for mp in "${mount_points[@]}"; do
  add_path "$mp"
done
for lp in "${library_paths[@]}"; do
  add_path "$lp"
done

sorted_paths=()
if [[ ${#filesystem_paths[@]} -gt 0 ]]; then
  mapfile -t sorted_paths < <(printf '%s\n' "${!filesystem_paths[@]}" | sort -u)
fi

if [[ "$flatpak_ready" == "true" && ${#sorted_paths[@]} -gt 0 ]]; then
  for app in "${apps[@]}"; do
    for path in "${sorted_paths[@]}"; do
      run_cmd flatpak --user override --filesystem="$path" "$app"
    done
    log "Applied Flatpak filesystem overrides for $app"
  done
elif [[ "$flatpak_ready" == "true" ]]; then
  log "No filesystem paths to apply for Flatpak overrides."
fi

bin_dir="$HOME/bin"
run_cmd mkdir -p "$bin_dir"
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
run_cmd chmod 0755 "$protontricks_gui"

protontricks_cli="$bin_dir/protontricks"
cat <<'PROTONTRICKS_CLI' > "$protontricks_cli"
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

exec flatpak run com.github.Matoking.protontricks --no-bwrap "$@"
PROTONTRICKS_CLI
run_cmd chmod 0755 "$protontricks_cli"
log "Protontricks wrappers present: gui=$protontricks_gui cli=$protontricks_cli"

wrapper_steam_dir=""
if [[ -d "$HOME/.steam/debian-installation" ]]; then
  wrapper_steam_dir="$HOME/.steam/debian-installation"
elif [[ -d "$HOME/.steam/steam" ]]; then
  wrapper_steam_dir="$HOME/.steam/steam"
elif [[ -d "$HOME/.local/share/Steam" ]]; then
  wrapper_steam_dir="$HOME/.local/share/Steam"
fi
log "Protontricks wrapper STEAM_DIR: ${wrapper_steam_dir:-unset}"

env_dir="$HOME/.config/environment.d"
run_cmd mkdir -p "$env_dir"
env_file="$env_dir/10-wolf-tools.conf"
cat <<ENV_FILE > "$env_file"
PATH=$HOME/bin:$PATH
ENV_FILE
log "Ensured PATH includes \$HOME/bin via $env_file"

applications_dir="$HOME/.local/share/applications"
run_cmd mkdir -p "$applications_dir"
cat <<'DESKTOP_ENTRY' > "$applications_dir/protontricks-gui.desktop"
[Desktop Entry]
Type=Application
Name=Protontricks (Container Safe)
Exec=/home/retro/bin/protontricks-gui
Icon=com.github.Matoking.protontricks
Categories=Game;Utility;
Terminal=false
DESKTOP_ENTRY

log "Bootstrap completed successfully."
if [[ "${WOLF_DEBUG_KEEPALIVE:-}" == "1" ]]; then
  log "WOLF_DEBUG_KEEPALIVE=1 set; keeping bootstrap process alive."
  sleep infinity
fi
exit 0
