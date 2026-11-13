#!/usr/bin/env bash
# backup.sh - dump the PostgreSQL database of the docker compose stack.
#
# Usage: scripts/backup.sh
#
# Writes BACKUP_DIR/<db>_<YYYYmmdd-HHMMSS>.dump (pg_dump custom format) and a
# .sha256 checksum next to it, checks the dump is readable, then deletes the
# dumps older than RETENTION_DAYS. Safe to run from cron (see README).
#
# Environment:
#   BACKUP_DIR      where dumps are written      (default: <repo>/backups)
#   RETENTION_DAYS  days a dump is kept          (default: 7)
#
# Exit codes: 0 ok, 1 dump or check failed, 3 docker missing or db not running
set -euo pipefail
umask 077   # dumps contain all the data: readable by the owner only

cd "$(dirname "$0")/.."
BACKUP_DIR="${BACKUP_DIR:-$PWD/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"

log() { echo "$(date '+%F %T') backup: $*"; }
die() { log "ERROR: $2" >&2; exit "$1"; }

command -v docker >/dev/null 2>&1 || die 3 "docker is not installed"
[[ -n "$(docker compose ps --status running -q db 2>/dev/null)" ]] \
  || die 3 "the db service is not running (docker compose up -d db)"

DB_NAME="$(docker compose exec -T db printenv POSTGRES_DB)"
mkdir -p "$BACKUP_DIR"
file="$BACKUP_DIR/${DB_NAME}_$(date '+%Y%m%d-%H%M%S').dump"
tmp="$file.part"
trap 'rm -f "$tmp"' EXIT

log "dumping database '$DB_NAME' to $file"
docker compose exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --format=custom' > "$tmp" \
  || die 1 "pg_dump failed"

# A dump that pg_restore cannot list is useless: check it before keeping it.
tables=$(docker compose exec -T db pg_restore --list < "$tmp" | grep ' TABLE ' | grep -vc ' TABLE DATA ' || true)
(( tables > 0 )) || die 1 "the dump contains no table, not keeping it"

mv "$tmp" "$file"
(cd "$BACKUP_DIR" && sha256sum "$(basename "$file")" > "$(basename "$file").sha256")
log "ok: $(du -h "$file" | cut -f1), $tables tables, checksum $(basename "$file").sha256"

deleted=$(find "$BACKUP_DIR" -maxdepth 1 -name "${DB_NAME}_*.dump*" -mtime +"$RETENTION_DAYS" -print -delete | wc -l)
log "retention ${RETENTION_DAYS}d: $deleted old file(s) deleted"
