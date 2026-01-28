FROM ghcr.io/games-on-whales/xfce:edge

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

USER root

COPY wolf-tools-bootstrap.sh /usr/local/bin/wolf-tools-bootstrap.sh
COPY wolf-tools-bootstrap.desktop /etc/xdg/autostart/wolf-tools-bootstrap.desktop

RUN chmod 0755 /usr/local/bin/wolf-tools-bootstrap.sh \
  && chmod 0644 /etc/xdg/autostart/wolf-tools-bootstrap.desktop

USER retro
