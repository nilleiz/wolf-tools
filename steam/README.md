# Steam Tools Image

This image extends the upstream `ghcr.io/games-on-whales/steam:edge` image with extra tooling (protontricks + Ludusavi) while preserving the upstream runtime behavior (same entrypoint, CMD, and default user). The image only adds files and packages; it does not override the startup logic.

## Build locally

```bash
docker build -t nillivanilli0815/wolf-tools-steam:edge ./steam
```

To pin a specific Ludusavi release (which updates the GitHub Releases tarball URL), set the `LUDUSAVI_VERSION` build argument:

```bash
docker build --build-arg LUDUSAVI_VERSION=0.30.0 -t nillivanilli0815/wolf-tools-steam:edge ./steam
```

## Run locally (troubleshooting)

```bash
docker run --rm -it \
  -e PROTON_LOG=1 \
  -e RUN_SWAY=true \
  -e GOW_REQUIRED_DEVICES="/dev/input/* /dev/dri/* /dev/nvidia*" \
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
[[profiles.apps]]
icon_png_path = 'https://games-on-whales.github.io/wildlife/apps/steam/assets/icon.png'
start_virtual_compositor = true
title = 'Steam'

    [profiles.apps.runner]
    base_create_json = '''{
  "HostConfig": {
    "IpcMode": "host",
    "CapAdd": ["SYS_ADMIN", "SYS_NICE", "SYS_PTRACE", "NET_RAW", "MKNOD", "NET_ADMIN"],
    "SecurityOpt": ["seccomp=unconfined", "apparmor=unconfined"],
    "Ulimits": [{"Name":"nofile", "Hard":10240, "Soft":10240}],
    "Privileged": false,
    "DeviceCgroupRules": ["c 13:* rmw", "c 244:* rmw"]
  }
}
'''
    devices = []
    env = [ 'PROTON_LOG=1', 'RUN_SWAY=true', 'GOW_REQUIRED_DEVICES=/dev/input/* /dev/dri/* /dev/nvidia*' ]
    image = 'ghcr.io/games-on-whales/steam:edge'
    mounts = [
      "/mnt/storage/games:/home/retro/games:rw",
      "/mnt/storage/downloads:/home/retro/downloads:rw",
    ]
    name = 'WolfSteam'
    ports = []
    type = 'docker'

[[profiles.apps]]
icon_png_path = 'https://games-on-whales.github.io/wildlife/apps/steam/assets/icon.png'
start_virtual_compositor = true
title = 'Steam (Tools)'

    [profiles.apps.runner]
    base_create_json = '''{
  "HostConfig": {
    "IpcMode": "host",
    "CapAdd": ["SYS_ADMIN", "SYS_NICE", "SYS_PTRACE", "NET_RAW", "MKNOD", "NET_ADMIN"],
    "SecurityOpt": ["seccomp=unconfined", "apparmor=unconfined"],
    "Ulimits": [{"Name":"nofile", "Hard":10240, "Soft":10240}],
    "Privileged": false,
    "DeviceCgroupRules": ["c 13:* rmw", "c 244:* rmw"]
  }
}
'''
    devices = []
    env = [ 'PROTON_LOG=1', 'RUN_SWAY=true', 'GOW_REQUIRED_DEVICES=/dev/input/* /dev/dri/* /dev/nvidia*' ]
    image = 'nillivanilli0815/wolf-tools-steam:edge'
    mounts = [
      "/mnt/storage/games:/home/retro/games:rw",
      "/mnt/storage/downloads:/home/retro/downloads:rw",
    ]
    name = 'WolfSteamTools'
    ports = []
    type = 'docker'
```

## Using the tools inside Steam

Once the Steam session is running, you can:

- Open a terminal in the Steam UI and run:
  - `protontricks --gui`
  - `ludusavi`
- Or use **Add a Non-Steam Game** and point to:
  - `/usr/local/bin/protontricks-gui`
  - `/usr/local/bin/ludusavi-gui`

## Notes on permissions

Protontricks and Ludusavi rely on Steam/Proton prefixes under your Steam library (e.g., `steamapps/compatdata`). Ensure those directories are writable for the default runtime user (typically UID/GID 1000) on the host mounts.
