FROM ghcr.io/games-on-whales/xfce:edge

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

USER root

RUN if ! getent group retro > /dev/null; then groupadd -g 1000 retro; fi \
  && if ! id -u retro > /dev/null 2>&1; then useradd -m -u 1000 -g 1000 -s /bin/bash retro; fi \
  && getent passwd retro > /dev/null \
  && test -d /home/retro

COPY wolf-tools-bootstrap.sh /usr/local/bin/wolf-tools-bootstrap.sh
COPY wolf-tools-bootstrap.desktop /etc/xdg/autostart/wolf-tools-bootstrap.desktop

RUN chmod 0755 /usr/local/bin/wolf-tools-bootstrap.sh \
  && chmod 0644 /etc/xdg/autostart/wolf-tools-bootstrap.desktop

USER retro
