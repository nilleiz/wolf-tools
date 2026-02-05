# Wolf Tools Monorepo

This repository currently contains the Wolf XFCE tools image.

## Images

| Image | Description | Folder |
| --- | --- | --- |
| XFCE tools image | XFCE-based Wolf image with bootstrap tooling for Protontricks and Ludusavi | `wolf-xfce-game-tools/` |

## Tagging & publishing

Images are tagged with:

- `edge`
- The short git SHA (for reproducible pinning)

GitHub Actions builds and pushes the XFCE tools image to Docker Hub.

## Build locally

```bash
docker build -t nillivanilli0815/wolf-xfce-tools:edge ./wolf-xfce-game-tools
```

## Usage with Wolf

Use the image in your Wolf app configuration by pointing an app entry to the appropriate image tag. See the image-specific README for example TOML snippets and runtime notes.
