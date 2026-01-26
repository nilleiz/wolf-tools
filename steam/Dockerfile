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
  && curl -fsSL -o /tmp/ludusavi.tar.gz \
    "https://github.com/mtkennerly/ludusavi/releases/download/v${LUDUSAVI_VERSION}/ludusavi-v${LUDUSAVI_VERSION}-linux-${LUDUSAVI_ARCH}.tar.gz" \
  && tar -xzf /tmp/ludusavi.tar.gz -C /usr/local/bin \
  && rm -f /tmp/ludusavi.tar.gz

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
