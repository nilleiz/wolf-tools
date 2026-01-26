# Steam Tools Image

This image extends the Steam Wolf image with tooling such as protontricks and Ludusavi.

## Build locally

```bash
docker build -t nillivanilli0815/wolf-tools-steam:edge ./steam
```

## Run locally (troubleshooting)

```bash
docker run --rm -it \
  -e PROTON_LOG=1 \
  -e RUN_SWAY=true \
  -e GOW_REQUIRED_DEVICES="/dev/input/* /dev/dri/* /dev/nvidia*" \
  -e FIX_PERMS=1 \
  -e PERMS_PATHS=/home/retro \
  -v /mnt/cachessd/wolf:/mnt/cachessd/wolf \
  -v /mnt/cachessd/wolf:/etc/wolf \
  -v /mnt/games:/home/retro/games \
  -v /mnt/cachessd/games_slow:/home/retro/games_slow \
  -v /mnt/downloadssd:/home/retro/downloadssd \
  nillivanilli0815/wolf-tools-steam:edge /bin/bash
```

## Wolf TOML example

Add a new app entry next to your existing Steam entry. The example below keeps the original Steam entry intact and adds a new "Steam (Tools)" entry.

```toml
[[apps]]
name = "Steam"
title = "Steam"
image = "ghcr.io/games-on-whales/steam:edge"

[[apps]]
name = "WolfSteamTools"
title = "Steam (Tools)"
image = "nillivanilli0815/wolf-tools-steam:edge"

[apps.env]
PROTON_LOG = "1"
RUN_SWAY = "true"
GOW_REQUIRED_DEVICES = "/dev/input/* /dev/dri/* /dev/nvidia*"
FIX_PERMS = "1"
PERMS_PATHS = "/home/retro"

[[apps.mounts]]
source = "/mnt/cachessd/wolf"
target = "/mnt/cachessd/wolf"

[[apps.mounts]]
source = "/mnt/cachessd/wolf"
target = "/etc/wolf"

[[apps.mounts]]
source = "/mnt/games"
target = "/home/retro/games"

[[apps.mounts]]
source = "/mnt/cachessd/games_slow"
target = "/home/retro/games_slow"

[[apps.mounts]]
source = "/mnt/downloadssd"
target = "/home/retro/downloadssd"
```

## Permissions troubleshooting

Bind-mounted paths must be writable by UID/GID 1000 on the host unless you are using CIFS/NFS mount options to map ownership. The entrypoint attempts to `chown` the bind-mounted paths at runtime, which requires the container to start as root and then drop privileges to the configured UID/GID.
