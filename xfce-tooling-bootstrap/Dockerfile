FROM ghcr.io/games-on-whales/xfce:edge AS upstream

FROM ghcr.io/games-on-whales/xfce:edge

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

ENV PUID=1000 \
  PGID=1000 \
  USER=retro \
  USERNAME=retro \
  HOME=/home/retro

COPY --from=upstream /etc/cont-init.d/10-setup_user.sh /etc/cont-init.d/10-setup_user.sh

COPY wolf-tools-bootstrap.sh /usr/local/bin/wolf-tools-bootstrap.sh
COPY wolf-tools-bootstrap.desktop /etc/xdg/autostart/wolf-tools-bootstrap.desktop

RUN chmod 0755 /usr/local/bin/wolf-tools-bootstrap.sh \
  && chmod 0644 /etc/xdg/autostart/wolf-tools-bootstrap.desktop \
  && bash -n /etc/cont-init.d/10-setup_user.sh
