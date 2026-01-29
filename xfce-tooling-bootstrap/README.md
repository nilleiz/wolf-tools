# Wolf XFCE Tools Bootstrap

This image extends the official Wolf XFCE image and adds a bootstrap that installs Protontricks and Ludusavi via Flatpak on first desktop start. It also configures Flatpak filesystem permissions for Steam and any `/mnt/*` mounts, and creates a ready-to-use Protontricks GUI launcher.

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
- Adds Flatpak filesystem overrides for:
  - The detected Steam root.
  - `~/.local/share/Steam` (canonical Steam path).
  - Every mountpoint under `/mnt/*` discovered at runtime.
  - Steam library paths from `libraryfolders.vdf`.
- Adds a Protontricks GUI launcher in the XFCE menu.

## Notes

- The image configures the upstream user-setup script via env vars so a `retro` user/group (UID/GID 1000) with `/home/retro` is created at startup.
- Steam must be launched at least once so `steamapps/libraryfolders.vdf` exists.
- A game must be launched at least once to create Proton compatdata prefixes (required for Protontricks).
- Host storage should be mounted under `/mnt/*` (arbitrary names are supported).
- Steam installs are typically available at `~/.steam/debian-installation` via Wolf's `profile_data` mount.

## Troubleshooting

- **Steam not detected yet:** Start Steam once, then restart the XFCE session. The bootstrap logs this and exits safely.
- **Bootstrap logs:** `~/.config/wolf-tools/bootstrap.log`
- **Verify Flatpak permissions:**
  ```bash
  flatpak --user override --show com.github.Matoking.protontricks
  flatpak --user override --show com.github.mtkennerly.ludusavi
  ```
