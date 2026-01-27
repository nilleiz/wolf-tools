# Steam Tools Image

This image extends the Steam Wolf image with tooling such as protontricks and Ludusavi. Ludusavi is installed from the pinned GitHub Releases linux tarball.

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
    env = [
      'PROTON_LOG=1',
      'RUN_SWAY=true',
      'GOW_REQUIRED_DEVICES=/dev/input/* /dev/dri/* /dev/nvidia*',
      'FIX_PERMS=1',
      'PERMS_PATHS=/home/retro',
    ]
    image = 'nillivanilli0815/wolf-tools-steam:edge'
    mounts = [
      "/mnt/storage/games:/home/retro/games:rw",
      "/mnt/storage/downloads:/home/retro/downloads:rw",
    ]
    name = 'WolfSteamTools'
    ports = []
    type = 'docker'
```

## Permissions troubleshooting

Bind-mounted paths must be writable by UID/GID 1000 on the host unless you are using CIFS/NFS mount options to map ownership. Mounting everything under `/home/retro` helps keep Steam paths consistent, but it does **not** change the host ownership/ACLs. Steam still writes to compatdata/pfx under `steamapps`, so ownership mismatches can break game launches.

The entrypoint’s permission fix is a best-effort `chown` over `PERMS_PATHS` and common Steam directories. This requires the container to start as root (Wolf `base_create_json` with `"User":"0:0"`) and then drops privileges to `RUN_AS_UID`/`RUN_AS_GID`.

### Recommendation

* **Keep `FIX_PERMS=1` (default)** if any of the mounted paths are not owned by UID/GID 1000 or are created by other services/users.
* **You can set `FIX_PERMS=0`** only when **all** mounted paths under `/home/retro` are already writable by UID/GID 1000 on the host.

#### Wolf TOML env snippet

```toml
env = [
  'FIX_PERMS=1',
  'PERMS_PATHS=/home/retro',
  'RUN_AS_UID=1000',
  'RUN_AS_GID=1000',
]
```
