# Excalidraw

Self-hosted Excalidraw editor for the homelab, deployed to `ds1` at
`https://excalidraw.jdealla.com`.

## Deployment

The fleet deployer clones this repository to `/mnt/storage/apps/excalidraw` and
runs Docker Compose. The official Excalidraw image binds only to host loopback
on port `8099`; Cloudflare Tunnel provides public HTTPS and Cloudflare Access
restricts the site to the owner's email.

The image is digest-pinned. Dependabot proposes reviewed digest updates weekly.
No environment file, database, or server-side storage is required.

## Data model

This is the official client-only self-hosted build. Drawings stay in the
browser or in exported `.excalidraw` files; this deployment does not provide
Excalidraw's server-backed sharing or real-time collaboration features. Export
important drawings if they need to survive browser-data loss or move between
devices.

## Local check

```bash
docker compose config --quiet
docker compose up -d
curl -fsS http://127.0.0.1:8099/ >/dev/null
docker compose down
```
