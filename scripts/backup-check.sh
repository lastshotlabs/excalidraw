#!/usr/bin/env bash
set -euo pipefail

app_dir=${EXCALIDRAW_APP_DIR:-/mnt/storage/apps/excalidraw}
nas_mount=${EXCALIDRAW_NAS_MOUNT:-/mnt/nas-backups}
compose_user=${EXCALIDRAW_COMPOSE_USER:-deploy}

if [[ $EUID -ne 0 ]]; then
  echo "backup check must run with sudo" >&2
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

const backupDir = process.env.BACKUP_DIR || "/app/backups";
const names = fs
  .readdirSync(backupDir)
  .filter((name) => /^excalidash-sqlite-.*\.db$/.test(name))
  .sort();

if (names.length === 0) throw new Error("no SQLite backup found");

const name = names[names.length - 1];
const file = path.join(backupDir, name);
const database = new Database(file, { readonly: true, fileMustExist: true });
try {
  const integrity = database.pragma("integrity_check", { simple: true });
  if (integrity !== "ok") throw new Error(`integrity_check returned ${integrity}`);

  const required = ["Collection", "Drawing", "SystemConfig", "User"];
  const tables = new Set(
    database
      .prepare("SELECT name FROM sqlite_master WHERE type = 'table'")
      .all()
      .map((row) => row.name),
  );
  const missing = required.filter((table) => !tables.has(table));
  if (missing.length > 0) throw new Error(`missing tables: ${missing.join(", ")}`);

  console.log(`backup valid: ${name} (${fs.statSync(file).size} bytes)`);
} finally {
  database.close();
}
NODE
