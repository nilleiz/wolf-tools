#!/usr/bin/env bash
set -u

LOG_DIR="$HOME/.config/wolf-tools"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/bootstrap.log"
exec >>"$LOG_FILE" 2>&1

echo "=== wolf-tools bootstrap start $(date -Is) ==="
echo "USER=$(id -un 2>/dev/null || echo unknown) UID=$(id -u 2>/dev/null || echo unknown) HOME=$HOME"
first_run=false
if [[ ! -f "$LOG_DIR/last-run" ]]; then
  first_run=true
fi
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
if [[ "$first_run" == "true" ]]; then
  log "Note: For non-Steam shortcuts, Ludusavi autodetection depends on the Steam shortcut name matching the PCGamingWiki title (e.g. rename 'ManorLords.exe' to 'Manor Lords')."
fi

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
  if ! flatpak --user remotes 2>/dev/null | awk '{print $1}' | grep -Fxq "flathub"; then
    if ! flatpak --user remote-add flathub https://flathub.org/repo/flathub.flatpakrepo; then
      log "Failed to add Flathub remote (continuing)."
    fi
  fi
fi

protontricks_app="com.github.Matoking.protontricks"
ludusavi_app="com.github.mtkennerly.ludusavi"
flatpak_apps=(
  "$protontricks_app"
  "$ludusavi_app"
)

if [[ "$flatpak_ready" == "true" ]]; then
  flatpak_install_args=()
  flatpak_install_help="$(flatpak install --help 2>/dev/null || true)"
  if echo "$flatpak_install_help" | grep -q -- '--noninteractive'; then
    flatpak_install_args+=(--noninteractive)
  elif echo "$flatpak_install_help" | grep -q -- '-y'; then
    flatpak_install_args+=(-y)
  fi
  for app in "${flatpak_apps[@]}"; do
    if ! flatpak info --user "$app" >/dev/null 2>&1; then
      log "Installing $app"
      if ! retry_cmd 3 flatpak --user install "${flatpak_install_args[@]}" flathub "$app"; then
        log "Install failed after retries: $app"
      fi
    else
      log "$app already installed"
    fi
  done
  log "Flatpak user list:"
  flatpak --user list || log "Failed to list installed Flatpaks"
  log "Protontricks version: $(flatpak run "$protontricks_app" --version 2>/dev/null || echo unavailable)"
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
  if [[ -f "$candidate/steamapps/libraryfolders.vdf" ]]; then
    STEAM_ROOT="$candidate"
    break
  fi
done

if [[ -z "$STEAM_ROOT" ]]; then
  log "Steam not detected yet; start Steam once to apply overrides."
else
  log "Detected Steam root: $STEAM_ROOT"

  canonical_steam="$HOME/.local/share/Steam"
  run_cmd mkdir -p "$HOME/.local/share"
  if [[ -w "$HOME/.local/share" ]]; then
    if ln -sfn "$STEAM_ROOT" "$canonical_steam" 2>/dev/null; then
      log "Ensured Steam symlink at $canonical_steam -> $STEAM_ROOT"
    else
      log "Unable to create Steam symlink at $canonical_steam (not writable?)."
    fi
  else
    log "Cannot write to $HOME/.local/share; skipping Steam symlink."
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
  if [[ ${#library_paths[@]} -gt 0 ]]; then
    log "Discovered Steam library roots from VDF: ${library_paths[*]}"
  else
    log "No existing Steam library roots found in $library_file"
  fi
else
  log "Steam library list not found yet at ${library_file:-unknown}"
fi

declare -A protontricks_paths=()
declare -A ludusavi_paths=()

add_path() {
  local -n target="$1"
  local path="$2"
  [[ -n "$path" ]] || return
  target["$path"]=1
}

if [[ -n "$STEAM_ROOT" ]]; then
  canonical_steam="$HOME/.local/share/Steam"
  add_path protontricks_paths "$STEAM_ROOT"
  add_path protontricks_paths "$canonical_steam"

  add_path ludusavi_paths "$STEAM_ROOT/steamapps"
  add_path ludusavi_paths "$STEAM_ROOT/steamapps/compatdata"
fi

for mp in "${mount_points[@]}"; do
  add_path protontricks_paths "$mp"
done

for lp in "${library_paths[@]}"; do
  add_path protontricks_paths "$lp"
  add_path ludusavi_paths "$lp/steamapps"
  add_path ludusavi_paths "$lp/steamapps/compatdata"
done

add_path ludusavi_paths "$HOME/.local/share/Steam"

sorted_protontricks_paths=()
sorted_ludusavi_paths=()
if [[ ${#protontricks_paths[@]} -gt 0 ]]; then
  mapfile -t sorted_protontricks_paths < <(printf '%s\n' "${!protontricks_paths[@]}" | sort -u)
fi
if [[ ${#ludusavi_paths[@]} -gt 0 ]]; then
  mapfile -t sorted_ludusavi_paths < <(printf '%s\n' "${!ludusavi_paths[@]}" | sort -u)
fi

if [[ "$flatpak_ready" == "true" && ${#sorted_protontricks_paths[@]} -gt 0 ]]; then
  for path in "${sorted_protontricks_paths[@]}"; do
    run_cmd flatpak --user override --filesystem="$path" "$protontricks_app"
  done
  log "Applied Flatpak filesystem overrides for $protontricks_app"
elif [[ "$flatpak_ready" == "true" ]]; then
  log "No filesystem paths to apply for Protontricks overrides."
fi

if [[ "$flatpak_ready" == "true" ]]; then
  run_cmd flatpak --user override --reset "$ludusavi_app"
  if [[ ${#sorted_ludusavi_paths[@]} -gt 0 ]]; then
    log "Ludusavi override paths: ${sorted_ludusavi_paths[*]}"
    for path in "${sorted_ludusavi_paths[@]}"; do
      run_cmd flatpak --user override --filesystem="$path" "$ludusavi_app"
    done
    log "Applied scoped Flatpak filesystem overrides for $ludusavi_app"
  else
    log "No filesystem paths to apply for Ludusavi overrides."
  fi
  log "Ludusavi permissions:"
  if flatpak info --show-permissions "$ludusavi_app" >/dev/null 2>&1; then
    while IFS= read -r line; do
      log "  $line"
    done < <(flatpak info --show-permissions "$ludusavi_app")
  else
    log "  unavailable"
  fi
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

config_dir="$HOME/.var/app/com.github.mtkennerly.ludusavi/config"
if [[ -d "$config_dir" ]]; then
  mapfile -t config_candidates < <(
    find "$config_dir" -maxdepth 3 -type f \( -iname '*config*' -o -iname '*.yaml' -o -iname '*.yml' -o -iname '*.toml' \) 2>/dev/null
  )
  if [[ ${#config_candidates[@]} -gt 0 ]]; then
    log "Ludusavi config candidates found; skipping exclude edits (unknown schema)."
  fi
fi

exec flatpak run com.github.mtkennerly.ludusavi
LUDUSAVI_WRAPPER
run_cmd chmod 0755 "$ludusavi_wrapper"
log "Ludusavi wrapper present: $ludusavi_wrapper"

legacy_ludusavi_wrapper="$bin_dir/ludusavi-steam"
if [[ -f "$legacy_ludusavi_wrapper" ]]; then
  run_cmd rm -f "$legacy_ludusavi_wrapper"
  log "Removed legacy Ludusavi wrapper at $legacy_ludusavi_wrapper"
fi

ludusavi_dump="$bin_dir/ludusavi-dump-steam-paths"
cat <<'LUDUSAVI_DUMP' > "$ludusavi_dump"
#!/usr/bin/env bash
set -euo pipefail

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

echo "STEAM_ROOT=${STEAM_ROOT:-unset}"

library_file=""
if [[ -n "$STEAM_ROOT" ]]; then
  library_file="$STEAM_ROOT/steamapps/libraryfolders.vdf"
fi
library_paths=()
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

if [[ ${#library_paths[@]} -gt 0 ]]; then
  echo "Library roots:"
  printf '  %s\n' "${library_paths[@]}"
else
  echo "Library roots: (none)"
fi

echo "Compatdata directories:"
compat_roots=()
if [[ -n "$STEAM_ROOT" ]]; then
  compat_roots+=("$STEAM_ROOT")
fi
compat_roots+=("${library_paths[@]}")

for root in "${compat_roots[@]}"; do
  compat_path="$root/steamapps/compatdata"
  if [[ -d "$compat_path" ]]; then
    echo "  $compat_path"
  fi
done

echo "Appmanifest counts:"
for root in "${compat_roots[@]}"; do
  steamapps_dir="$root/steamapps"
  if [[ -d "$steamapps_dir" ]]; then
    shopt -s nullglob
    manifests=("$steamapps_dir"/appmanifest_*.acf)
    shopt -u nullglob
    echo "  $steamapps_dir: ${#manifests[@]} manifest(s)"
  fi
done
LUDUSAVI_DUMP
run_cmd chmod 0755 "$ludusavi_dump"
log "Ludusavi diagnostics helper present: $ludusavi_dump"

env_dir="$HOME/.config/environment.d"
run_cmd mkdir -p "$env_dir"
env_file="$env_dir/10-wolf-tools.conf"
cat <<ENV_FILE > "$env_file"
PATH=$HOME/bin:$PATH
ENV_FILE
log "Ensured PATH includes \$HOME/bin via $env_file"

applications_dir="$HOME/.local/share/applications"
run_cmd mkdir -p "$applications_dir"
run_cmd rm -f \
  "$applications_dir/protontricks-gui.desktop" \
  "$applications_dir/ludusavi-steam.desktop"

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

run_cmd update-desktop-database "$applications_dir"

log "Bootstrap completed successfully."
if [[ "${WOLF_DEBUG_KEEPALIVE:-}" == "1" ]]; then
  log "WOLF_DEBUG_KEEPALIVE=1 set; keeping bootstrap process alive."
  sleep infinity
fi
exit 0
