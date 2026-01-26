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
  && LUDUSAVI_URL="$(python3 -c $'import json, os\narch = os.environ.get(\"LUDUSAVI_ARCH\", \"\").lower()\narch_aliases = {\"x86_64\": [\"x86_64\", \"x64\", \"amd64\"], \"aarch64\": [\"aarch64\", \"arm64\"]}\npreferred_exts = [\".tar.xz\", \".tar.gz\", \".zip\"]\nwith open(\"/tmp/ludusavi.json\", \"r\", encoding=\"utf-8\") as fh:\n    data = json.load(fh)\nassets = data.get(\"assets\", [])\nchoices = []\nfor asset in assets:\n    name = asset.get(\"name\", \"\")\n    lower_name = name.lower()\n    if \"linux\" not in lower_name:\n        continue\n    if arch and not any(token in lower_name for token in arch_aliases.get(arch, [])):\n        continue\n    url = asset.get(\"browser_download_url\", \"\")\n    if not url:\n        continue\n    for idx, ext in enumerate(preferred_exts):\n        if lower_name.endswith(ext):\n            choices.append((idx, url))\n            break\nchoices.sort(key=lambda item: item[0])\nprint(choices[0][1] if choices else \"\")')" \
  && if [[ -z "${LUDUSAVI_URL}" ]]; then \
    echo "Unable to locate a Ludusavi linux asset for ${LUDUSAVI_ARCH} in ${LUDUSAVI_API_URL}" >&2; \
    python3 -c $'import json\nwith open(\"/tmp/ludusavi.json\", \"r\", encoding=\"utf-8\") as fh:\n    data = json.load(fh)\nprint(\"Available assets:\")\nfor asset in data.get(\"assets\", []):\n    print(f\"- {asset.get('\"'\"'name'\"'\"', '')}\")'; \
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
