#!/usr/bin/env bash
# restore.sh - restore a dump made by backup.sh into the docker compose stack.
#
# Usage: scripts/restore.sh <file.dump> [--yes]
#
# Steps: verify the checksum and the dump, take a safety backup of the current
# database, stop the API, restore in a single transaction (all or nothing),
# restart the API and check it answers.
#
# Exit codes: 0 ok, 1 restore or check failed, 2 bad usage or invalid file,
#             3 docker missing or db not running
set -euo pipefail

log() { echo "$(date '+%F %T') restore: $*"; }
die() { log "ERROR: $2" >&2; exit "$1"; }

[[ $# -ge 1 ]] || die 2 "usage: scripts/restore.sh <file.dump> [--yes]"
file="$(realpath "$1")" || die 2 "file not found: $1"
[[ -f "$file" ]] || die 2 "file not found: $1"
confirm="${2:-}"

cd "$(dirname "$0")/.."
API_URL="${API_URL:-http://localhost:8080/api/workshops}"

command -v docker >/dev/null 2>&1 || die 3 "docker is not installed"
[[ -n "$(docker compose ps --status running -q db 2>/dev/null)" ]] \
  || die 3 "the db service is not running (docker compose up -d db)"

# 1. Check the file before touching anything
if [[ -f "$file.sha256" ]]; then
  (cd "$(dirname "$file")" && sha256sum --quiet -c "$(basename "$file").sha256") \
    || die 2 "checksum mismatch: the dump is corrupted"
  log "checksum ok"
else
  log "warning: no $file.sha256, checksum not verified"
fi
docker compose exec -T db pg_restore --list < "$file" >/dev/null || die 2 "not a valid pg_dump file"

DB_NAME="$(docker compose exec -T db printenv POSTGRES_DB)"
if [[ "$confirm" != "--yes" ]]; then
  [[ -t 0 ]] || die 2 "not interactive: add --yes to confirm"
  read -r -p "Replace ALL data of database '$DB_NAME' with $(basename "$file")? [y/N] " answer
  [[ "$answer" == [yY] ]] || die 2 "aborted"
fi

# 2. Safety net: keep the current state, so a wrong restore can be undone
log "safety backup of the current database"
BACKUP_DIR="$PWD/backups/pre-restore" RETENTION_DAYS=30 scripts/backup.sh

# 3. Restore with the API stopped, so nothing writes during the restore
log "stopping the API"
docker compose stop app
log "restoring $(basename "$file") into '$DB_NAME'"
if ! docker compose exec -T db sh -c \
    'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists --single-transaction --exit-on-error' < "$file"; then
  docker compose start app
  die 1 "pg_restore failed: nothing was changed (single transaction), API restarted"
fi

# 4. Restart and check
log "starting the API"
docker compose start app
for _ in $(seq 1 30); do
  if curl -sf -o /dev/null "$API_URL"; then
    count=$(docker compose exec -T db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "select count(*) from workshop_model"')
    log "ok: API answers on $API_URL, $count workshop(s) in the database"
    exit 0
  fi
  sleep 2
done
die 1 "the API does not answer on $API_URL after the restore (docker compose logs app)"
