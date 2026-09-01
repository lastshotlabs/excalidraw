#!/usr/bin/env bash
set -euo pipefail

env_file=${EXCALIDRAW_ENV_FILE:-/etc/homeserver/excalidraw.env}
data_dir=${EXCALIDRAW_DATA_DIR:-/mnt/storage/appdata/excalidraw/prisma}
backup_dir=${EXCALIDRAW_BACKUP_DIR:-/mnt/nas-backups/backups/excalidraw}

if [[ ! -r $env_file ]]; then
  echo "missing readable production env: $env_file" >&2
  exit 1
fi

for variable in JWT_SECRET CSRF_SECRET API_KEY_HASH_PEPPER; do
  if ! grep -Eq "^${variable}=.{32,}$" "$env_file"; then
    echo "production env is missing a valid $variable" >&2
    exit 1
  fi
done

for directory in "$data_dir" "$backup_dir"; do
  if [[ ! -d $directory ]]; then
    echo "missing persistent directory: $directory" >&2
    exit 1
  fi
done

docker compose config --quiet
