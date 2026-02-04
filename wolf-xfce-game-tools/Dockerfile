FROM ghcr.io/games-on-whales/xfce:edge AS upstream

FROM ghcr.io/games-on-whales/xfce:edge

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

ENV PUID=1000 \
  PGID=1000 \
  USER=retro \
  USERNAME=retro \
  HOME=/home/retro

COPY --from=upstream /etc/cont-init.d/10-setup_user.sh /etc/cont-init.d/10-setup_user.sh

RUN if ! command -v flatpak >/dev/null 2>&1; then \
    if command -v apt-get >/dev/null 2>&1; then \
      apt-get update \
      && apt-get install -y flatpak \
      && rm -rf /var/lib/apt/lists/*; \
    elif command -v apk >/dev/null 2>&1; then \
      apk add --no-cache flatpak; \
    else \
      echo "flatpak missing and no supported package manager found" >&2; \
      exit 1; \
    fi; \
  fi

COPY wolf-tools-bootstrap.sh /usr/local/bin/wolf-tools-bootstrap.sh
COPY wolf-tools-bootstrap.desktop /etc/xdg/autostart/wolf-tools-bootstrap.desktop
COPY wolf-tools-bootstrap-run.desktop /usr/share/applications/wolf-tools-bootstrap-run.desktop

RUN chmod 0755 /usr/local/bin/wolf-tools-bootstrap.sh \
  && chmod 0644 /etc/xdg/autostart/wolf-tools-bootstrap.desktop \
  && chmod 0644 /usr/share/applications/wolf-tools-bootstrap-run.desktop \
  && mkdir -p /tmp/.X11-unix /run/user/1000 \
  && chmod 1777 /tmp/.X11-unix \
  && chmod 700 /run/user/1000 \
  && chown 1000:1000 /run/user/1000 \
  && bash -n /etc/cont-init.d/10-setup_user.sh \
  && test -x /usr/local/bin/wolf-tools-bootstrap.sh \
  && test -f /etc/xdg/autostart/wolf-tools-bootstrap.desktop \
  && test -f /usr/share/applications/wolf-tools-bootstrap-run.desktop \
  && cat /etc/xdg/autostart/wolf-tools-bootstrap.desktop
