# Wolf Tools Monorepo

This repository is a monorepo for multiple Wolf-compatible tool images. Each image lives in its own subfolder, has its own Dockerfile and documentation, and can be built and published independently.

## Images

| Image | Description | Folder |
| --- | --- | --- |
| Steam tools image | Steam base with extra tooling for troubleshooting and save management | `steam/` |

## Tagging & publishing

Images are tagged with:

- `edge`
- The short git SHA (for reproducible pinning)

The GitHub Actions workflow builds and pushes the current Steam tools image to Docker Hub.

## Usage with Wolf

Use the image in your Wolf app configuration by pointing an app entry to the appropriate image tag. See the image-specific README for example TOML snippets.
