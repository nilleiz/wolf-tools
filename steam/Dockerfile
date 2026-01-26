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
  && LUDUSAVI_API_URL="https://api.github.com/repos/mtkennerly/ludusavi/releases/tags/v${LUDUSAVI_VERSION}" \
  && if ! curl -fL -o /tmp/ludusavi.json "${LUDUSAVI_API_URL}"; then \
    STATUS="$(curl -sSL -o /dev/null -w "%{http_code}" "${LUDUSAVI_API_URL}" || true)"; \
    echo "Failed to fetch Ludusavi release metadata from ${LUDUSAVI_API_URL} (status ${STATUS})" >&2; \
    exit 1; \
  fi \
  && export LUDUSAVI_ARCH \
  && LUDUSAVI_URL="$(python3 -c 'import json, os; arch=os.environ.get("LUDUSAVI_ARCH","").lower(); arch_aliases={"x86_64":["x86_64","x64","amd64"],"aarch64":["aarch64","arm64"]}; preferred_exts=[".tar.xz",".tar.gz",".zip"]; data=json.load(open("/tmp/ludusavi.json","r",encoding="utf-8")); choices=[]; \
    \
    for asset in data.get("assets",[]): \
        name=asset.get("name",""); lower=name.lower(); \
        \
        if "linux" not in lower: \
            continue; \
        \
        if arch and not any(token in lower for token in arch_aliases.get(arch, [])): \
            continue; \
        \
        url=asset.get("browser_download_url",""); \
        \
        if not url: \
            continue; \
        \
        for idx, ext in enumerate(preferred_exts): \
            \
            if lower.endswith(ext): \
                choices.append((idx, url, name)); \
                break; \
    \
    choices.sort(key=lambda item: item[0]); print(choices[0][1] if choices else "")')" \
  && if [[ -z "${LUDUSAVI_URL}" ]]; then \
    echo "Unable to locate a Ludusavi linux asset for ${LUDUSAVI_ARCH} in ${LUDUSAVI_API_URL}" >&2; \
    python3 -c 'import json; data=json.load(open("/tmp/ludusavi.json","r",encoding="utf-8")); print("Available assets:"); \
      \
      for asset in data.get("assets", []): \
          print(f"- {asset.get(\"name\", \"\")}")'; \
    exit 1; \
  fi \
  && if ! curl -fL -o /tmp/ludusavi.archive "${LUDUSAVI_URL}"; then \
    STATUS="$(curl -sSL -o /dev/null -w "%{http_code}" "${LUDUSAVI_URL}" || true)"; \
    echo "Failed to download Ludusavi from ${LUDUSAVI_URL} (status ${STATUS})" >&2; \
    exit 1; \
  fi \
  && mkdir -p /tmp/ludusavi-extract \
  && case "${LUDUSAVI_URL}" in \
    *.zip) \
      unzip -l /tmp/ludusavi.archive; \
      unzip -q /tmp/ludusavi.archive -d /tmp/ludusavi-extract ;; \
    *.tar.gz|*.tar.xz) \
      tar -tf /tmp/ludusavi.archive; \
      tar -xf /tmp/ludusavi.archive -C /tmp/ludusavi-extract ;; \
    *) \
      echo "Unsupported Ludusavi archive format: ${LUDUSAVI_URL}" >&2; \
      exit 1 ;; \
  esac \
  && LUDUSAVI_BIN="$(find /tmp/ludusavi-extract -type f -name ludusavi -print -quit)" \
  && if [[ -z "${LUDUSAVI_BIN}" ]]; then \
    echo "Ludusavi binary not found in archive from ${LUDUSAVI_URL}" >&2; \
    exit 1; \
  fi \
  && install -m 0755 "${LUDUSAVI_BIN}" /usr/local/bin/ludusavi \
  && rm -rf /tmp/ludusavi.archive /tmp/ludusavi-extract

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN ludusavi --version

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
