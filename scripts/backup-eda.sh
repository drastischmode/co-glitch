#!/bin/bash
# Backup Script für EDA-Projekte (KiCad, QElectroTech, etc.)
# Wird von make eda-backup aufgerufen und kann in den täglichen Backup-Cron integriert werden

set -euo pipefail

EDA_PROJECTS_DIR="${HOME}/projects/eda"
BACKUP_DIR="${BACKUP_DIR:-$(pwd)/backups/eda/$(date +%F)}"

mkdir -p "$BACKUP_DIR"

echo "=== EDA Backup $(date -u +%Y-%m-%dT%H:%M:%SZ) ===" > "$BACKUP_DIR/manifest.txt"

if [ ! -d "$EDA_PROJECTS_DIR" ]; then
    echo "Kein EDA-Projektverzeichnis gefunden: $EDA_PROJECTS_DIR" >> "$BACKUP_DIR/manifest.txt"
    exit 0
fi

count=0
for project in "$EDA_PROJECTS_DIR"/*/; do
    [ -d "$project" ] || continue
    name=$(basename "$project")
    
    # Nur Git-Repos sichern (sauberer Stand)
    if [ -d "$project/.git" ]; then
        echo "Backing up EDA project: $name"
        # Git bundle erstellen (komplettes Repo in einer Datei)
        git -C "$project" bundle create "$BACKUP_DIR/${name}.bundle" --all 2>&1
        if [ $? -eq 0 ]; then
            echo "  git bundle: ${name}.bundle ($(stat -c%s "$BACKUP_DIR/${name}.bundle") bytes)" >> "$BACKUP_DIR/manifest.txt"
            count=$((count + 1))
        else
            echo "  WARN: git bundle fehlgeschlagen für $name" >> "$BACKUP_DIR/manifest.txt"
        fi
        # Zusätzlich: Working tree als tar.gz (für uncommited changes)
        tar czf "$BACKUP_DIR/${name}-worktree.tar.gz" --exclude='.git' -C "$project" . 2>/dev/null
        echo "  worktree tar: ${name}-worktree.tar.gz ($(stat -c%s "$BACKUP_DIR/${name}-worktree.tar.gz") bytes)" >> "$BACKUP_DIR/manifest.txt"
    else
        echo "  SKIP: $name (kein Git-Repo)" >> "$BACKUP_DIR/manifest.txt"
    fi
done

# SHA256 checksums
(cd "$BACKUP_DIR" && sha256sum * > manifest.sha256 2>/dev/null || true)

echo "EDA Backup abgeschlossen: $count Projekte" >> "$BACKUP_DIR/manifest.txt"
echo "BACKUP_DIR=$BACKUP_DIR"