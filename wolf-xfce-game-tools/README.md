# Wolf XFCE Tools Bootstrap

This image extends the official Wolf XFCE image and adds a bootstrap that installs Protontricks and Ludusavi via Flatpak before the XFCE session starts. It configures Flatpak filesystem permissions for Steam and `/mnt`, creates ready-to-use launchers, and removes duplicate menu entries.

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

- Installs Protontricks and Ludusavi via Flatpak (user scope) before the first desktop session so menu entries are ready immediately.
- Adds Flatpak filesystem overrides for Protontricks and Ludusavi covering:
  - `/mnt` for Wolf game library mounts.
  - `~/.steam` and `~/.local/share/Steam` for Steam metadata access.
- Ensures `~/.local/share/Steam` is a symlink to `~/.steam/debian-installation`.
- Overrides the Flatpak desktop entries with `~/.local/share/applications/com.github.Matoking.protontricks.desktop` and `~/.local/share/applications/com.github.mtkennerly.ludusavi.desktop` so the XFCE menu shows only the working launchers with original names.
- Adds a manual "Wolf Tools Bootstrap (Run)" desktop entry for debugging.
- Wraps Protontricks to set `STEAM_DIR`, `GTK_USE_PORTAL=0`, and `GIO_USE_VFS=local` for container-friendly behavior.

## Notes

- The image configures the upstream user-setup script via env vars so a `retro` user/group (UID/GID 1000) with `/home/retro` is created at startup.
- Steam must be launched at least once so `steamapps/libraryfolders.vdf` exists.
- A game must be launched at least once to create Proton compatdata prefixes (required for Protontricks).
- Host storage should be mounted under `/mnt/*` (arbitrary names are supported).
- Steam installs are typically available at `~/.steam/debian-installation` via Wolf's `profile_data` mount.
- Protontricks runs with `GTK_USE_PORTAL=0`, `GIO_USE_VFS=local`, and `STEAM_DIR` set to `~/.steam/debian-installation` for container-friendly behavior.
- Protontricks defaults to `--no-bwrap` because non-setuid bubblewrap requires unprivileged user namespaces that many container hosts do not provide. To opt back into bwrap, launch `flatpak run com.github.Matoking.protontricks --gui` or set `WOLF_TOOLS_PROTONTRICKS_BWRAP=1` before using the Protontricks launcher.
- For Ludusavi, launch the standard menu entry so Flatpak permissions stay minimal and backup previews finish promptly.
- If you already have Ludusavi backups, copy them into `/home/retro/ludusavi-backup` before restoring (for example via a bind mount).
- For non-Steam shortcuts, Ludusavi autodetection depends on the Steam shortcut name matching the PCGamingWiki title (e.g. rename “ManorLords.exe” to “Manor Lords”).

## Troubleshooting

- **Bootstrap logs:** `~/.config/wolf-tools/bootstrap.log`.
- **Manual trigger:** Run "Wolf Tools Bootstrap (Run)" from the menu to re-run the setup.
- **Pre-session hook verification:** `/etc/cont-init.d/20-wolf-tools-bootstrap.sh` should exist and be executable in the image.
- **Autostart fallback verification:** `/etc/xdg/autostart/wolf-tools-bootstrap.desktop` should exist in the image.
- **Verify Flatpak permissions:**
  ```bash
  flatpak --user override --show com.github.Matoking.protontricks
  flatpak --user override --show com.github.mtkennerly.ludusavi
  ```
