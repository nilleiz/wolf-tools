#!/usr/bin/env bash
set -euo pipefail

FIX_PERMS="${FIX_PERMS:-1}"
RUN_AS_UID="${RUN_AS_UID:-1000}"
RUN_AS_GID="${RUN_AS_GID:-1000}"
PERMS_PATHS="${PERMS_PATHS:-/home/retro}"

COMMON_PATHS=(
  "/home/retro/.steam"
  "/home/retro/.steam/root"
  "/home/retro/.steam/steam"
  "/home/retro/.local/share/Steam"
  "/home/retro/.local/share/Steam/steamapps"
  "/home/retro/.local/share/Steam/config"
)

if [[ "${FIX_PERMS}" == "1" ]]; then
  for path in ${PERMS_PATHS}; do
    if [[ -e "${path}" ]]; then
      chown -R "${RUN_AS_UID}:${RUN_AS_GID}" "${path}"
    fi
  done

  for path in "${COMMON_PATHS[@]}"; do
    if [[ -e "${path}" ]]; then
      chown -R "${RUN_AS_UID}:${RUN_AS_GID}" "${path}"
    fi
  done
fi

exec gosu "${RUN_AS_UID}:${RUN_AS_GID}" "$@"
