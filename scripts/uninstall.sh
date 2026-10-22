#!/bin/bash
# Uninstall Script für co-glitch Client Stack
# Stoppt Stack und entfernt Container, optional Volumes

set -euo pipefail

PURGE=false
FORCE=false

for arg in "$@"; do
    case $arg in
        --purge) PURGE=true ;;
        --force) FORCE=true ;;
        *) echo "Unbekannte Option: $arg"; exit 1 ;;
    esac
done

echo "=== co-glitch Uninstall ==="

if [ "$FORCE" = false ]; then
    echo ""
    echo "Dies entfernt:"
    echo "  - Alle Client-Container (n8n, Forgejo, Postiz, Supabase, Monitoring, etc.)"
    echo "  - Voice-Container (Whisper)"
    if [ "$PURGE" = true ]; then
        echo "  - ALLE Docker Volumes (DATENVERLUST!): n8n, Forgejo, Postiz, Supabase DB, etc."
    else
        echo "  - Docker Volumes bleiben erhalten (Daten bleiben)"
    fi
    echo "  - Docker Networks (co-glitch-*)"
    echo ""
    read -rp "Wirklich deinstallieren? [j/N] " -n 1
    echo
    if [[ ! $REPLY =~ ^[Jj]$ ]]; then
        echo "Abbruch."
        exit 0
    fi
fi

# 1. Stacks stoppen
echo "1. Stacks stoppen..."
make down-all 2>/dev/null || true

# 2. Volumes löschen (nur bei --purge)
if [ "$PURGE" = true ]; then
    echo "2. Volumes löschen (--purge)..."
    for vol in $(docker volume ls --filter "label=co-glitch.tier=client" -q); do
        docker volume rm "$vol" 2>/dev/null || true
    done
    for vol in $(docker volume ls --filter "label=co-glitch.tier=vps" -q); do
        docker volume rm "$vol" 2>/dev/null || true
    done
else
    echo "2. Volumes bleiben erhalten (nutze --purge zum Löschen)"
fi

# 3. Networks löschen
echo "3. Networks löschen..."
for net in co-glitch-backend co-glitch-frontend co-glitch-ai co-glitch-voice co-glitch-vps; do
    docker network rm "$net" 2>/dev/null || true
done

# 4. Images löschen (optional, nur bei --purge)
if [ "$PURGE" = true ]; then
    echo "4. Project-spezifische Images löschen..."
    for img in $(docker images --filter "reference=co-glitch*" -q); do
        docker rmi "$img" 2>/dev/null || true
    done
fi

# 5. systemd Services deaktivieren (falls installiert)
echo "5. Systemd Services prüfen..."
for svc in keepalive opencode; do
    if systemctl --user is-enabled "$svc" 2>/dev/null; then
        systemctl --user disable --now "$svc" 2>/dev/null || true
        echo "   ✓ $svc deaktiviert"
    fi
    if systemctl is-enabled "$svc" 2>/dev/null; then
        sudo systemctl disable --now "$svc" 2>/dev/null || true
        echo "   ✓ $svc (system) deaktiviert"
    fi
done

# 6. Aufräumen
echo "6. Docker aufräumen..."
docker system prune -f

echo ""
echo "=== Uninstall abgeschlossen ==="
if [ "$PURGE" = true ]; then
    echo "ALLE Daten entfernt. Neuinstallation: make gen-secrets && make client-setup && make up-client"
else
    echo "Daten in Volumes erhalten. Neuinstallation: make up-client"
fi