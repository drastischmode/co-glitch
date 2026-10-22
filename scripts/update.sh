#!/bin/bash
# Update Script für co-glitch Client Stack
# Aktualisiert Git-Repo, zieht neue Images, startet Stack neu

set -euo pipefail

FORCE=false
if [[ "${1:-}" == "--force" ]]; then
    FORCE=true
fi

echo "=== co-glitch Update ==="

# 1. Git Pull
echo "1. Git Repository aktualisieren..."
if git status --porcelain | grep -q .; then
    if [ "$FORCE" = true ]; then
        echo "   ⚠ Lokale Änderungen werden verworfen (--force)"
        git reset --hard HEAD
        git pull
    else
        echo "   ⚠ Lokale Änderungen gefunden. Commit oder stash zuerst, oder --force nutzen."
        git status --short
        exit 1
    fi
else
    git pull
fi

# 2. Docker Images pullen
echo "2. Docker Images aktualisieren..."
docker compose -f docker/client/docker-compose.yml pull
docker compose -f docker/voice/docker-compose.yml pull

# 3. Stack neu starten (rolling update)
echo "3. Client-Stack neu starten..."
docker compose -f docker/client/docker-compose.yml up -d --remove-orphans

# 4. Healthcheck warten
echo "4. Warten auf Healthchecks..."
for i in {1..60}; do
    HEALTHY=true
    for service in supabase-db supabase-kong n8n forgejo postiz uptime-kuma dozzle beszel cadvisor; do
        STATUS=$(docker compose -f docker/client/docker-compose.yml ps --format json "$service" 2>/dev/null | jq -r '.[0].Health // "none"' 2>/dev/null || echo "none")
        if [ "$STATUS" != "healthy" ] && [ "$STATUS" != "none" ]; then
            HEALTHY=false
            break
        fi
    done
    if [ "$HEALTHY" = true ]; then
        echo "   ✓ Alle Services healthy"
        break
    fi
    sleep 2
    if [ $i -eq 60 ]; then
        echo "   ⚠ Timeout: Nicht alle Services healthy nach 120s"
        docker compose -f docker/client/docker-compose.yml ps
    fi
done

# 5. Voice Stack (falls läuft)
if docker compose -f docker/voice/docker-compose.yml ps | grep -q "Up"; then
    echo "5. Voice-Stack neu starten..."
    docker compose -f docker/voice/docker-compose.yml up -d
fi

# 6. Aufräumen
echo "6. Nicht mehr genutzte Images entfernen..."
docker image prune -f

echo ""
echo "=== Update abgeschlossen ==="
make client-health