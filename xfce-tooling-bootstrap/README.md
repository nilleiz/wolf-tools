# Wolf XFCE Tools Bootstrap

This image extends the official Wolf XFCE image and adds a bootstrap that installs Protontricks and Ludusavi via Flatpak on first desktop start. It configures Flatpak filesystem permissions for Steam and any `/mnt/*` mounts, creates ready-to-use Protontricks launchers, and provides a Steam-scoped Ludusavi wrapper to avoid runaway scans in container environments.

## Image

`nillivanilli0815/wolf-xfce-tools`

## Usage (Wolf config.toml)

Point your XFCE app image to this image:

```toml
[apps.xfce]
image = "nillivanilli0815/wolf-xfce-tools:edge"
env = { PUID = "1000", PGID = "1000", USER = "retro", USERNAME = "retro", HOME = "/home/retro" }
```

## What it does

- Installs Protontricks and Ludusavi via Flatpak (user scope) on the first desktop start.
- Adds Flatpak filesystem overrides for Protontricks covering:
  - The detected Steam root.
  - `~/.local/share/Steam` (canonical Steam path).
  - Every mountpoint under `/mnt/*` discovered at runtime.
  - Steam library paths from `libraryfolders.vdf`.
- Adds a Steam-scoped Ludusavi wrapper that resets overrides and grants access only to `steamapps` and `compatdata` locations plus minimal Steam metadata directories.
- Adds Protontricks GUI launchers and a Ludusavi (Steam scoped) launcher in the XFCE menu.
- Adds a manual "Wolf Tools Bootstrap (Run)" desktop entry for debugging.
- Wraps Protontricks to default to `--no-bwrap` in containerized environments.
- Adds a diagnostic helper at `~/bin/ludusavi-dump-steam-paths` to list detected Steam roots, library folders, compatdata directories, and appmanifest counts.

## Notes

- The image configures the upstream user-setup script via env vars so a `retro` user/group (UID/GID 1000) with `/home/retro` is created at startup.
- Steam must be launched at least once so `steamapps/libraryfolders.vdf` exists.
- A game must be launched at least once to create Proton compatdata prefixes (required for Protontricks).
- Host storage should be mounted under `/mnt/*` (arbitrary names are supported).
- Steam installs are typically available at `~/.steam/debian-installation` via Wolf's `profile_data` mount.
- Protontricks runs with `--no-bwrap` by default to avoid bubblewrap namespace failures in containers. To opt back into bwrap, run `flatpak run com.github.Matoking.protontricks` directly or remove the flag from `~/bin/protontricks` and `~/bin/protontricks-gui`.
- For Ludusavi, prefer launching "Ludusavi (Steam scoped)" so Flatpak permissions stay minimal and backup previews finish promptly.

## Troubleshooting

- **Steam not detected yet:** Start Steam once, then restart the XFCE session. The bootstrap logs this and exits safely.
- **Bootstrap logs:** `~/.config/wolf-tools/bootstrap.log` (look for `=== bootstrap start ... ===`).
- **Manual trigger:** Run "Wolf Tools Bootstrap (Run)" from the menu to re-run the bootstrap.
- **Autostart verification:** `/etc/xdg/autostart/wolf-tools-bootstrap.desktop` should exist in the image.
- **Verify Flatpak permissions:**
  ```bash
  flatpak --user override --show com.github.Matoking.protontricks
  flatpak --user override --show com.github.mtkennerly.ludusavi
  ```
