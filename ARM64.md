# ARM64 Architecture Guide

[![Build ARM64 Images](https://github.com/jarvisxyz/project-nomad-synology/actions/workflows/build-arm64.yml/badge.svg)](https://github.com/jarvisxyz/project-nomad-synology/actions/workflows/build-arm64.yml)

## Why ARM64?

The upstream [Project N.O.M.A.D.](https://github.com/Crosstalk-Solutions/project-nomad) publishes Docker images for **x86-64 (amd64)** only. Several popular Synology NAS models use **ARM64** (Cortex-A55) CPUs and cannot run x86-64 images natively.

This repository's GitHub Actions workflow builds and publishes **multi-arch images** (`linux/amd64` + `linux/arm64`) from the upstream source weekly, making Project N.O.M.A.D. fully functional on ARM64 Synology devices.

---

## Affected Synology Models

The following Synology models use ARM64 (Cortex-A55) processors and require the images from this repo:

| Model | CPU | RAM | Notes |
|---|---|---|---|
| DS124 | RTD1619B (ARM64) | 1 GB | 1-bay |
| DS224+ | RTD1619B (ARM64) | 2 GB | 2-bay, most popular home NAS |
| DS423 | RTD1619B (ARM64) | 2 GB | 4-bay |
| DS423+ | RTD1619B (ARM64) | 2 GB | 4-bay |

> **x86-64 models** (DS923+, DS1522+, DS1823xs+, RS1221+, etc.) work with the upstream images directly — they do not need this repo's images.

---

## Available Images

This repo's workflow builds and pushes three images to GitHub Container Registry (GHCR):

| Image | Tag | Source |
|---|---|---|
| `ghcr.io/jarvisxyz/project-nomad` | `latest` | `upstream/Dockerfile` |
| `ghcr.io/jarvisxyz/project-nomad-sidecar-updater` | `latest` | `upstream/install/sidecar-updater/` |
| `ghcr.io/jarvisxyz/project-nomad-disk-collector` | `latest` | `upstream/install/disk-collector/` |

All images are multi-arch manifests (`linux/amd64` + `linux/arm64`). Docker will automatically pull the correct variant for your platform.

---

## How It Works

The workflow (`.github/workflows/build-arm64.yml`):

1. **Triggers:** Weekly on Sundays at 02:00 UTC, on push to `main`, or manually via `workflow_dispatch`
2. **Checks out** this repo and the upstream `Crosstalk-Solutions/project-nomad` repo (at build time — not stored here)
3. **Uses QEMU** to emulate ARM64 for cross-compilation
4. **Builds** each Dockerfile with `docker buildx` for both `linux/amd64` and `linux/arm64`
5. **Pushes** to `ghcr.io/jarvisxyz/...` with `latest` tag

Build cache (`type=gha`) is used between runs to keep builds fast.

---

## Using the Images

### If you're on ARM64 (DS224+, DS423+, DS124, DS423)

The default `docker-compose.yml` in this repo already uses the `ghcr.io/jarvisxyz/...` images. No changes needed.

```yaml
# These are the defaults in docker-compose.yml
image: ghcr.io/jarvisxyz/project-nomad:latest
image: ghcr.io/jarvisxyz/project-nomad-sidecar-updater:latest
image: ghcr.io/jarvisxyz/project-nomad-disk-collector:latest
```

### If you're on x86-64

You can either:
- **Keep the defaults** — the `ghcr.io/jarvisxyz/...` images also include `linux/amd64`, so they work fine
- **Swap to upstream images** — uncomment the `ghcr.io/crosstalk-solutions/...` lines in `docker-compose.yml` for a slightly smaller pull that comes straight from the project maintainers

```yaml
# Swap these in docker-compose.yml for upstream images on x86-64:
image: ghcr.io/crosstalk-solutions/project-nomad:latest
image: ghcr.io/crosstalk-solutions/project-nomad-sidecar-updater:latest
image: ghcr.io/crosstalk-solutions/project-nomad-disk-collector:latest
```

---

## Checking Build Status

- [GitHub Actions — Build ARM64 Images](https://github.com/jarvisxyz/project-nomad-synology/actions/workflows/build-arm64.yml)
- [GHCR Packages](https://github.com/jarvisxyz?tab=packages)

To manually trigger a rebuild:
1. Go to **Actions** → **Build ARM64 Images**
2. Click **Run workflow** → **Run workflow**
