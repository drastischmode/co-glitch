#!/bin/bash
# Backup Script für co-glitch Client Stack
# Erstellt Backup von PostgreSQL (Supabase) und Docker Volumes

set -euo pipefail

BACKUP_DIR="${1:-./backups/$(date +%Y-%m-%d)}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "=== co-glitch Backup ==="
echo "Backup-Verzeichnis: $BACKUP_DIR"
echo "Timestamp: $TIMESTAMP"

mkdir -p "$BACKUP_DIR"

# 1. PostgreSQL Dump (supabase-db)
echo "1. PostgreSQL Dump erstellen..."
if docker compose -f docker/client/docker-compose.yml ps supabase-db | grep -q "healthy"; then
    docker compose -f docker/client/docker-compose.yml exec -T supabase-db \
        pg_dump -U postgres -d postgres --no-owner --no-privileges \
        > "$BACKUP_DIR/supabase_db_${TIMESTAMP}.sql"
    echo "   ✓ supabase_db_${TIMESTAMP}.sql"
else
    echo "   ⚠ supabase-db nicht healthy, überspringe DB-Dump"
fi

# 2. Volumes als tar.gz
echo "2. Docker Volumes sichern..."
for volume in n8n_data forgejo_data postiz_data kuma_data beszel_data ollama_data; do
    if docker volume inspect "co-glitch-client_${volume}" >/dev/null 2>&1; then
        docker run --rm \
            -v "co-glitch-client_${volume}:/data:ro" \
            -v "$(pwd)/$BACKUP_DIR:/backup" \
            alpine tar czf "/backup/${volume}_${TIMESTAMP}.tar.gz" -C /data .
        echo "   ✓ ${volume}_${TIMESTAMP}.tar.gz"
    else
        echo "   ⚠ Volume co-glitch-client_${volume} nicht gefunden"
    fi
done

# 3. Supabase Kong Config sichern
echo "3. Kong Config sichern..."
cp docker/client/supabase-kong.yml "$BACKUP_DIR/supabase-kong.yml"

# 4. .env sichern (ohne Secrets in Git, aber für Restore wichtig)
echo "4. .env sichern..."
cp .env "$BACKUP_DIR/env_backup_${TIMESTAMP}"

# 5. Manifest erstellen
echo "5. Manifest erstellen..."
cat > "$BACKUP_DIR/MANIFEST_${TIMESTAMP}.txt" <<EOF
co-glitch Backup Manifest
=========================
Datum: $(date)
Host: $(hostname)
Docker Compose Projekt: co-glitch-client

Dateien:
EOF
ls -la "$BACKUP_DIR" >> "$BACKUP_DIR/MANIFEST_${TIMESTAMP}.txt"

echo ""
echo "=== Backup abgeschlossen ==="
echo "Backup liegt in: $BACKUP_DIR"
echo ""
echo "Zum Restore:"
echo "  make restore DATE=$(basename $BACKUP_DIR)"