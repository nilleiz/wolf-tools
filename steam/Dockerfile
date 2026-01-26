FROM ghcr.io/games-on-whales/steam:edge

ARG TARGETARCH
ARG LUDUSAVI_VERSION=0.30.0

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    protontricks \
    winetricks \
    python3 \
    yad \
    zenity \
    cabextract \
    unzip \
    p7zip-full \
    xdg-utils \
    gosu \
    curl \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

RUN case "${TARGETARCH}" in \
    amd64) LUDUSAVI_ARCH=x86_64 ;; \
    arm64) LUDUSAVI_ARCH=aarch64 ;; \
    *) echo "Unsupported TARGETARCH: ${TARGETARCH}"; exit 1 ;; \
  esac \
  && LUDUSAVI_URL="https://github.com/mtkennerly/ludusavi/releases/download/v${LUDUSAVI_VERSION}/ludusavi-v${LUDUSAVI_VERSION}-linux.tar.gz" \
  && echo "Downloading Ludusavi from ${LUDUSAVI_URL}" \
  && if ! curl -fL -o /tmp/ludusavi.archive "${LUDUSAVI_URL}"; then \
    STATUS="$(curl -sSL -o /dev/null -w "%{http_code}" "${LUDUSAVI_URL}" || true)"; \
    echo "Failed to download Ludusavi from ${LUDUSAVI_URL} (status ${STATUS})" >&2; \
    exit 1; \
  fi \
  && mkdir -p /tmp/ludusavi-extract \
7 po  && tar -tf /tmp/ludusavi.archive \
  && tar -xf /tmp/ludusavi.archive -C /tmp/ludusavi-extract \
  && LUDUSAVI_BIN="$(find /tmp/ludusavi-extract -type f -name ludusavi -print -quit)" \
  && if [[ -z "${LUDUSAVI_BIN}" ]]; then \
    echo "Ludusavi binary not found in archive from ${LUDUSAVI_URL}" >&2; \
    exit 1; \
  fi \
  && install -m 0755 "${LUDUSAVI_BIN}" /usr/local/bin/ludusavi \
  && rm -rf /tmp/ludusavi.archive /tmp/ludusavi-extract

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN /usr/local/bin/ludusavi --version

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
