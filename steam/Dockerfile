FROM ghcr.io/games-on-whales/steam:edge

ARG LUDUSAVI_VERSION=0.30.0
ARG STEAM_RUNTIME_USER=retro

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

USER root

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    python3 \
    python3-venv \
    python3-pip \
    winetricks \
    yad \
    zenity \
    cabextract \
    unzip \
    p7zip-full \
    xdg-utils \
    curl \
    ca-certificates \
  && if apt-cache show protontricks >/dev/null 2>&1; then \
    apt-get install -y --no-install-recommends protontricks; \
  else \
    python3 -m pip install --no-cache-dir pipx; \
    PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install --pip-args='--no-cache-dir' protontricks; \
  fi \
  && rm -rf /var/lib/apt/lists/*

RUN LUDUSAVI_URL="https://github.com/mtkennerly/ludusavi/releases/download/v${LUDUSAVI_VERSION}/ludusavi-v${LUDUSAVI_VERSION}-linux.tar.gz" \
  && curl -fL -o /tmp/ludusavi.tar.gz "${LUDUSAVI_URL}" \
  && mkdir -p /tmp/ludusavi \
  && tar -xzf /tmp/ludusavi.tar.gz -C /tmp/ludusavi \
  && LUDUSAVI_BIN="$(find /tmp/ludusavi -type f -name ludusavi -print -quit)" \
  && if [[ -z "${LUDUSAVI_BIN}" ]]; then \
    echo "Ludusavi binary not found in ${LUDUSAVI_URL}" >&2; \
    exit 1; \
  fi \
  && install -m 0755 "${LUDUSAVI_BIN}" /usr/local/bin/ludusavi \
  && rm -rf /tmp/ludusavi /tmp/ludusavi.tar.gz

RUN cat <<'PROTONTRICKS_GUI' > /usr/local/bin/protontricks-gui \
  && chmod 0755 /usr/local/bin/protontricks-gui
#!/usr/bin/env bash
set -euo pipefail
exec protontricks --gui "$@"
PROTONTRICKS_GUI

RUN cat <<'LUDUSAVI_GUI' > /usr/local/bin/ludusavi-gui \
  && chmod 0755 /usr/local/bin/ludusavi-gui
#!/usr/bin/env bash
set -euo pipefail
if [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
  exec ludusavi "$@"
fi
ludusavi --help
LUDUSAVI_GUI

RUN protontricks --version
RUN ludusavi --version

USER ${STEAM_RUNTIME_USER}
