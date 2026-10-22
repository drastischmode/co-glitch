#!/usr/bin/env bash
set -euo pipefail
BACKUP_DIR="${BACKUP_DIR:-./backups/$(date +%F)}"
mkdir -p "$BACKUP_DIR"
echo "backup start $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$BACKUP_DIR/manifest.txt"
DB=$(docker ps -q --filter name=supabase-db | head -1)
if [ -z "$DB" ]; then
  echo "pg_dump skipped: supabase-db not running" >> "$BACKUP_DIR/manifest.txt"
else
  PG_USER=$(docker exec "$DB" printenv POSTGRES_USER 2>/dev/null || echo postgres)
  DBS=$(docker exec "$DB" psql -U "$PG_USER" -d postgres -tAc "SELECT datname FROM pg_database WHERE datistemplate=false" 2>/dev/null | grep -vx postgres | grep -vx template0 | grep -vx template1)
  for D in $DBS; do
    if docker exec "$DB" pg_dump -U "$PG_USER" "$D" > "$BACKUP_DIR/$D.sql" 2>"$BACKUP_DIR/$D.err"; then
      gzip -f "$BACKUP_DIR/$D.sql"
      echo "pg_dump ok ($D) $(stat -c%s "$BACKUP_DIR/$D.sql.gz") bytes" >> "$BACKUP_DIR/manifest.txt"
      rm -f "$BACKUP_DIR/$D.err"
    else
      echo "pg_dump FAILED ($D): $(head -1 "$BACKUP_DIR/$D.err" 2>/dev/null)" >> "$BACKUP_DIR/manifest.txt"
      rm -f "$BACKUP_DIR/$D.sql"
    fi
  done
fi
for v in n8n_data forgejo_data postiz_data kuma_data; do
  VNAME=$(docker volume ls -q | grep -m1 "$v$" || true)
  if [ -n "$VNAME" ]; then
    docker run --rm -v "$VNAME:/data:ro" -v "$(pwd)/$BACKUP_DIR:/backup" alpine tar czf "/backup/$v.tar.gz" -C /data . 2>/dev/null || true
    echo "volume $v archived" >> "$BACKUP_DIR/manifest.txt"
  fi
done
( cd "$BACKUP_DIR" && sha256sum * > manifest.sha256 2>/dev/null || true )
echo "backup done $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$BACKUP_DIR/manifest.txt"
echo "BACKUP_DIR=$BACKUP_DIR"
