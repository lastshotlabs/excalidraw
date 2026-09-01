# Excalidraw

Private, persistent Excalidraw workspace for the homelab, deployed to `ds1` at
`https://excalidraw.jdealla.com` using ExcaliDash.

## What is included

- Named drawings stored on the server and available across devices.
- Collections, search, version history, restore, and import/export.
- Embedded Excalidraw editor and real-time collaboration support.
- Standard `.excalidraw` archival format, avoiding a proprietary data format.

Cloudflare Access restricts the entire hostname to `jdealla@gmail.com`. The
application therefore uses ExcaliDash's shared single-user mode and does not
show a second login screen. Sharing and collaboration links remain behind the
same Cloudflare Access policy unless that policy is deliberately expanded.

## Deployment

The fleet deployer clones this repository to `/mnt/storage/apps/excalidraw` and
runs Docker Compose. Only the frontend publishes a host port, bound to
`127.0.0.1:8099`; its nginx instance proxies `/api` and `/socket.io` to the
private backend container. Cloudflare Tunnel supplies public HTTPS.

Production secrets live at `/etc/homeserver/excalidraw.env`, owned by `deploy`
with mode `0600`. Persistent paths are outside the Git checkout:

- `/mnt/storage/appdata/excalidraw/prisma` — live SQLite database and runtime secrets.
- `/mnt/nas-backups/backups/excalidraw` — nightly SQLite backups on ds2's NFS mount.

Backup commands retain the application's UID and use ds1's `jdd` group (GID
`1000`) for private write access to the root-squashed NFS directory.

The current ExcaliDash release and both image indexes are digest-pinned.
Dependabot proposes reviewed image updates weekly.

## Retention and recovery

Drawing history is retained for 30 days. A consistent SQLite online backup runs
nightly at `04:00 UTC` and keeps 30 days of copies on ds2. ExcaliDash
v0.6.0's built-in scheduled backup has an upstream SQLite checkpoint defect,
so a host systemd timer invokes the same database library without that broken
checkpoint call. Create and verify a backup on demand from ds1 with:

```bash
sudo /mnt/storage/apps/excalidraw/scripts/backup-now.sh
sudo /mnt/storage/apps/excalidraw/scripts/backup-check.sh
```

Install the checked-in timer once with:

```bash
sudo install -m 0644 ops/excalidraw-backup.service /etc/systemd/system/
sudo install -m 0644 ops/excalidraw-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now excalidraw-backup.timer
```

The dashboard can also export a portable archive whose drawings remain plain
`.excalidraw` data. Keep an occasional downloaded export for defense in depth.

## Configuration

Create `/etc/homeserver/excalidraw.env` on ds1 without printing the secrets:

```bash
sudo install -m 0600 -o deploy -g deploy /dev/null /etc/homeserver/excalidraw.env
sudo bash -c 'umask 077; printf "JWT_SECRET=%s\nCSRF_SECRET=%s\nAPI_KEY_HASH_PEPPER=%s\n" "$(openssl rand -hex 32)" "$(openssl rand -hex 32)" "$(openssl rand -hex 32)" > /etc/homeserver/excalidraw.env'
sudo chown deploy:deploy /etc/homeserver/excalidraw.env
```

Pushes to `main` go to ds1's signed fleet webhook. The deployer verifies the
signature and placement manifest before pulling the commit and recreating the
Compose project.

## Local validation

Override the production-only paths when testing on another machine:

```bash
EXCALIDRAW_ENV_FILE=/tmp/excalidraw.env \
EXCALIDRAW_DATA_DIR=/tmp/excalidraw-data \
EXCALIDRAW_BACKUP_DIR=/tmp/excalidraw-backups \
docker compose config --quiet
```

ExcaliDash is currently beta software. Keep the pinned upgrade flow and verify
backups before every version change.
