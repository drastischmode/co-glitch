#!/bin/bash
# Restore Script für co-glitch Client Stack
# Stellt PostgreSQL (Supabase) und Docker Volumes aus Backup wieder her

set -euo pipefail

BACKUP_DATE="${1:-}"

if [ -z "$BACKUP_DATE" ]; then
    echo "Usage: $0 <backup-date>"
    echo "Beispiel: $0 2026-10-22"
    echo ""
    echo "Verfügbare Backups:"
    ls -d ./backups/*/ 2>/dev/null | sed 's|./backups/||; s|/||' | sort -r || echo "  Keine Backups gefunden"
    exit 1
fi

BACKUP_DIR="./backups/$BACKUP_DATE"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "FEHLER: Backup-Verzeichnis $BACKUP_DIR nicht gefunden"
    echo "Verfügbare Backups:"
    ls -d ./backups/*/ 2>/dev/null | sed 's|./backups/||; s|/||' | sort -r
    exit 1
fi

echo "=== co-glitch Restore ==="
echo "Backup: $BACKUP_DIR"
echo ""

# Bestätigung
read -rp "WARNUNG: Dies überschreibt alle aktuellen Daten! Fortfahren? [j/N] " -n 1
echo
if [[ ! $REPLY =~ ^[Jj]$ ]]; then
    echo "Abbruch."
    exit 0
fi

# 1. Stack stoppen
echo "1. Client-Stack stoppen..."
make down-client

# 2. PostgreSQL wiederherstellen
echo "2. PostgreSQL wiederherstellen..."
SQL_FILE=$(ls "$BACKUP_DIR"/supabase_db_*.sql 2>/dev/null | head -1)
if [ -f "$SQL_FILE" ]; then
    # DB Container starten (nur DB)
    docker compose -f docker/client/docker-compose.yml up -d supabase-db
    sleep 5
    # Warten bis healthy
    for i in {1..30}; do
        if docker compose -f docker/client/docker-compose.yml ps supabase-db | grep -q "healthy"; then
            break
        fi
        sleep 2
    done
    # Restore
    docker compose -f docker/client/docker-compose.yml exec -T supabase-db \
        psql -U postgres -d postgres < "$SQL_FILE"
    echo "   ✓ PostgreSQL restore abgeschlossen"
else
    echo "   ⚠ Kein SQL-Dump gefunden in $BACKUP_DIR"
fi

# 3. Volumes wiederherstellen
echo "3. Docker Volumes wiederherstellen..."
for volume in n8n_data forgejo_data postiz_data kuma_data beszel_data ollama_data; do
    TAR_FILE=$(ls "$BACKUP_DIR/${volume}_"*.tar.gz 2>/dev/null | head -1)
    if [ -f "$TAR_FILE" ]; then
        # Volume löschen falls existiert
        docker volume rm "co-glitch-client_${volume}" 2>/dev/null || true
        # Volume neu erstellen
        docker volume create "co-glitch-client_${volume}"
        # Restore
        docker run --rm \
            -v "co-glitch-client_${volume}:/data" \
            -v "$(pwd)/$BACKUP_DIR:/backup:ro" \
            alpine tar xzf "/backup/$(basename $TAR_FILE)" -C /data
        echo "   ✓ $volume wiederhergestellt"
    else
        echo "   ⚠ Kein Backup für $volume gefunden"
    fi
done

# 4. Kong Config wiederherstellen
echo "4. Kong Config wiederherstellen..."
if [ -f "$BACKUP_DIR/supabase-kong.yml" ]; then
    cp "$BACKUP_DIR/supabase-kong.yml" docker/client/supabase-kong.yml
    echo "   ✓ supabase-kong.yml wiederhergestellt"
fi

# 5. .env wiederherstellen (optional)
echo "5. .env prüfen..."
if [ -f "$BACKUP_DIR/env_backup_${BACKUP_DATE}" ]; then
    read -rp "   .env aus Backup wiederherstellen? [j/N] " -n 1
    echo
    if [[ $REPLY =~ ^[Jj]$ ]]; then
        cp "$BACKUP_DIR/env_backup_${BACKUP_DATE}" .env
        echo "   ✓ .env wiederhergestellt"
    fi
fi

# 6. Stack starten
echo "6. Client-Stack starten..."
make up-client

echo ""
echo "=== Restore abgeschlossen ==="
echo "Prüfe Status mit: make client-health"