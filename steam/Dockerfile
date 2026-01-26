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
  && LUDUSAVI_BASE_URL="https://github.com/mtkennerly/ludusavi/releases/download/v${LUDUSAVI_VERSION}" \
  && LUDUSAVI_ASSET="" \
  && for ASSET in \
    "ludusavi-v${LUDUSAVI_VERSION}-linux-${LUDUSAVI_ARCH}.tar.xz" \
    "ludusavi-v${LUDUSAVI_VERSION}-linux-${LUDUSAVI_ARCH}.tar.gz" \
    "ludusavi-${LUDUSAVI_VERSION}-linux-${LUDUSAVI_ARCH}.tar.xz" \
    "ludusavi-${LUDUSAVI_VERSION}-linux-${LUDUSAVI_ARCH}.tar.gz" \
    "ludusavi-v${LUDUSAVI_VERSION}-linux-${LUDUSAVI_ARCH}.zip" \
    "ludusavi-${LUDUSAVI_VERSION}-linux-${LUDUSAVI_ARCH}.zip"; do \
      LUDUSAVI_URL="${LUDUSAVI_BASE_URL}/${ASSET}"; \
      if curl -fL -o /tmp/ludusavi.archive "${LUDUSAVI_URL}"; then \
        LUDUSAVI_ASSET="${ASSET}"; \
        break; \
      fi; \
      STATUS="$(curl -sSL -o /dev/null -w "%{http_code}" "${LUDUSAVI_URL}" || true)"; \
      echo "Failed to download Ludusavi from ${LUDUSAVI_URL} (status ${STATUS})" >&2; \
    done \
  && if [[ -z "${LUDUSAVI_ASSET}" ]]; then \
    echo "Unable to download Ludusavi release asset from ${LUDUSAVI_BASE_URL}" >&2; \
    exit 1; \
  fi \
  && mkdir -p /tmp/ludusavi-extract \
  && case "${LUDUSAVI_ASSET}" in \
    *.zip) \
      unzip -l /tmp/ludusavi.archive; \
      unzip -q /tmp/ludusavi.archive -d /tmp/ludusavi-extract ;; \
    *.tar.gz|*.tar.xz) \
      tar -tf /tmp/ludusavi.archive; \
      tar -xf /tmp/ludusavi.archive -C /tmp/ludusavi-extract ;; \
    *) \
      echo "Unsupported Ludusavi archive format: ${LUDUSAVI_ASSET}" >&2; \
      exit 1 ;; \
  esac \
  && LUDUSAVI_BIN="$(find /tmp/ludusavi-extract -type f -name ludusavi -print -quit)" \
  && if [[ -z "${LUDUSAVI_BIN}" ]]; then \
    echo "Ludusavi binary not found in archive from ${LUDUSAVI_BASE_URL}/${LUDUSAVI_ASSET}" >&2; \
    exit 1; \
  fi \
  && install -m 0755 "${LUDUSAVI_BIN}" /usr/local/bin/ludusavi \
  && rm -rf /tmp/ludusavi.archive /tmp/ludusavi-extract

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN ludusavi --version

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
