FROM ghcr.io/games-on-whales/xfce:edge

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

USER root

RUN if ! getent group retro > /dev/null; then \
    if getent group 1000 > /dev/null; then \
      groupadd -o -g 1000 retro; \
    else \
      groupadd -g 1000 retro; \
    fi; \
  fi \
  && if ! id -u retro > /dev/null 2>&1; then \
    if getent passwd 1000 > /dev/null; then \
      useradd -o -m -u 1000 -g 1000 -s /bin/bash retro; \
    else \
      useradd -m -u 1000 -g 1000 -s /bin/bash retro; \
    fi; \
  fi \
  && getent passwd retro > /dev/null \
  && test -d /home/retro \
  && if [[ -f /etc/cont-init.d/10-setup_user.sh ]]; then \
      sed -i '2i\\if id -u retro > /dev/null 2>&1; then\\n  echo \"[skip] retro already exists; skipping setup_user\"\\n  exit 0\\nfi\\n' /etc/cont-init.d/10-setup_user.sh; \
    fi

COPY wolf-tools-bootstrap.sh /usr/local/bin/wolf-tools-bootstrap.sh
COPY wolf-tools-bootstrap.desktop /etc/xdg/autostart/wolf-tools-bootstrap.desktop

RUN chmod 0755 /usr/local/bin/wolf-tools-bootstrap.sh \
  && chmod 0644 /etc/xdg/autostart/wolf-tools-bootstrap.desktop
