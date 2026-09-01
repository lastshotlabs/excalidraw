#!/usr/bin/env bash
set -euo pipefail

app_dir=${EXCALIDRAW_APP_DIR:-/mnt/storage/apps/excalidraw}
nas_mount=${EXCALIDRAW_NAS_MOUNT:-/mnt/nas-backups}
compose_user=${EXCALIDRAW_COMPOSE_USER:-deploy}

if [[ $EUID -ne 0 ]]; then
  echo "backup must run with sudo" >&2
  exit 1
fi

if ! mountpoint -q "$nas_mount"; then
  echo "$nas_mount is not mounted" >&2
  exit 1
fi

compose_home=$(getent passwd "$compose_user" | cut -d: -f6)
compose_env=("HOME=$compose_home")
for variable in EXCALIDRAW_ENV_FILE EXCALIDRAW_DATA_DIR EXCALIDRAW_BACKUP_DIR; do
  if [[ -n ${!variable:-} ]]; then
    compose_env+=("$variable=${!variable}")
  fi
done

sudo -u "$compose_user" env "${compose_env[@]}" docker compose --project-directory "$app_dir" \
  exec --user 1001:1000 -T backend node - <<'NODE'
const fs = require("fs");
const path = require("path");
const Database = require("better-sqlite3");

const databaseUrl = process.env.DATABASE_URL || "file:/app/prisma/dev.db";
if (!databaseUrl.startsWith("file:")) {
  throw new Error("backup supports only SQLite file: DATABASE_URL values");
}

const sourcePath = path.resolve(databaseUrl.slice("file:".length));
const backupDir = process.env.BACKUP_DIR || "/app/backups";
const retentionDays = Number(process.env.BACKUP_RETENTION_DAYS || 30);
const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
const target = path.join(backupDir, `excalidash-sqlite-${timestamp}.db`);

fs.mkdirSync(backupDir, { recursive: true, mode: 0o700 });
const source = new Database(sourcePath, { readonly: true, fileMustExist: true });
source
  .backup(target)
  .then(() => {
    fs.chmodSync(target, 0o600);
    if (Number.isFinite(retentionDays) && retentionDays > 0) {
      const cutoff = Date.now() - retentionDays * 24 * 60 * 60 * 1000;
      for (const name of fs.readdirSync(backupDir)) {
        if (!/^excalidash-sqlite-.*\.db$/.test(name)) continue;
        const file = path.join(backupDir, name);
        if (fs.statSync(file).mtimeMs < cutoff) fs.unlinkSync(file);
      }
    }
    console.log(`backup complete: ${target}`);
  })
  .finally(() => source.close());
NODE
