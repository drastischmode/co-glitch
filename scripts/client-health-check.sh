#!/bin/bash
# Client Health Check - prüft nur Client-Dienste
# Exit Code 0 = keine kritischen FAILs, 1 = mind. ein kritischer FAIL
#
# 4-Zustände-Modell:
#   healthy              - Healthcheck bestanden
#   running (no check)   - Container läuft, kein Healthcheck definiert
#   unhealthy            - Healthcheck fehlgeschlagen (kritisch)
#   not started (profile)- Dienst gehört zu nicht aktivem Profil

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

HEALTHY=0
RUNNING_NO_CHECK=0
UNHEALTHY=0
NOT_STARTED=0
CRITICAL_FAIL=0

check() {
    local name="$1"
    local cmd="$2"
    if eval "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}[OK]${NC} $name"
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $name"
        CRITICAL_FAIL=$((CRITICAL_FAIL+1))
        return 1
    fi
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

echo "=== Client Health Check ==="
echo ""

# 1. Docker Daemon
echo "1. Docker Daemon:"
check "Docker läuft" "systemctl is-active --quiet docker"
check "Docker erreichbar" "docker info --format '{{.ServerVersion}}' >/dev/null"

# 2. UFW
echo ""
echo "2. Firewall:"
check "UFW Service aktiv" "systemctl is-active --quiet ufw"
warn_check() {
    local name="$1"
    local cmd="$2"
    if eval "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}[OK]${NC} $name"
        return 0
    else
        echo -e "${YELLOW}[WARN]${NC} $name"
        return 0  # Nicht kritisch
    fi
}
warn_check "UFW Forward Policy ACCEPT (Docker)" "grep -q '^DEFAULT_FORWARD_POLICY=\"ACCEPT\"' /etc/default/ufw"

# 3. Container Health (label=co-glitch.tier=client)
echo ""
echo "3. Container (co-glitch.tier=client):"

# Nur Container aus dem "client" Profil zählen als kritisch
# Container aus "client-extended" Profil sind optional
CLIENT_CONTAINERS=$(docker ps --filter "label=co-glitch.tier=client" --format "{{.Names}} {{.Labels}}" 2>/dev/null || true)

if [ -z "$CLIENT_CONTAINERS" ]; then
    warn "Keine Client-Container gefunden (Stack gestartet?)"
else
    # Für jeden Container prüfen: Health-Status + Profil
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        NAME=$(echo "$line" | awk '{print $1}')
        LABELS=$(echo "$line" | cut -d' ' -f2-)
        
        # Profil-Label auslesen
        PROFILE=$(echo "$LABELS" | grep -o 'com.docker.compose.profile=[^,]*' | cut -d= -f2 | head -1 || echo "client")
        
        # Health-Status
        STATUS=$(docker inspect "$NAME" --format '{{.State.Health.Status}}' 2>/dev/null || echo "no-healthcheck")
        STATUS=$(echo "$STATUS" | tr -d '

' | xargs)
        RUNNING=$(docker inspect "$NAME" --format '{{.State.Running}}' 2>/dev/null || echo "false")
        RUNNING=$(echo "$RUNNING" | tr -d '

' | xargs)
        
        if [ "$STATUS" = "healthy" ]; then
            echo -e "${GREEN}[OK]${NC} $NAME (healthy, profile: $PROFILE)"
            HEALTHY=$((HEALTHY+1))
        elif [ "$STATUS" = "starting" ]; then
            echo -e "${YELLOW}[WAIT]${NC} $NAME (starting..., profile: $PROFILE)"
            # starting zählt nicht als healthy, aber auch nicht als fail
        elif [ "$STATUS" = "unhealthy" ]; then
            echo -e "${RED}[FAIL]${NC} $NAME (unhealthy, profile: $PROFILE)"
            UNHEALTHY=$((UNHEALTHY+1))
            # Nur kritisch, wenn im "client" Profil (Default)
            if [ "$PROFILE" = "client" ] || [ -z "$PROFILE" ]; then
                CRITICAL_FAIL=$((CRITICAL_FAIL+1))
            else
                info "$NAME ist in extended-Profil, wird nicht als kritisch gewertet"
            fi
        elif [ "$STATUS" = "no-healthcheck" ]; then
            if [ "$RUNNING" = "true" ]; then
                echo -e "${YELLOW}[RUNNING]${NC} $NAME (running, kein healthcheck, profile: $PROFILE)"
                RUNNING_NO_CHECK=$((RUNNING_NO_CHECK+1))
                # Nicht kritisch - Container läuft, hat aber keinen Healthcheck
            else
                echo -e "${RED}[FAIL]${NC} $NAME (not running, profile: $PROFILE)"
                CRITICAL_FAIL=$((CRITICAL_FAIL+1))
            fi
        else
            echo -e "${RED}[FAIL]${NC} $NAME ($STATUS, profile: $PROFILE)"
            CRITICAL_FAIL=$((CRITICAL_FAIL+1))
        fi
    done <<< "$CLIENT_CONTAINERS"
fi

# 4. Nicht gestartete Dienste aus extended-Profil anzeigen (informativ)
EXTENDED_SERVICES="postiz beszel-agent"
for svc in $EXTENDED_SERVICES; do
    if ! docker ps --filter "label=com.docker.compose.service=$svc" -q 2>/dev/null | grep -q .; then
        NOT_STARTED=$((NOT_STARTED+1))
    fi
done

# 5. HTTP Endpunkte (nur für im client-Profil laufende Dienste)
echo ""
echo "4. HTTP Endpunkte:"
http_check() {
    local name="$1" svc="$2" url="$3"
    if ! docker ps --filter "label=com.docker.compose.service=$svc" -q 2>/dev/null | grep -q .; then
        # Prüfen ob im extended-Profil
        if echo "$EXTENDED_SERVICES" | grep -qw "$svc"; then
            echo -e "${BLUE}[NOT STARTED]${NC} $name (profile: client-extended)"
        else
            echo -e "${YELLOW}[SKIP]${NC} $name (Container '$svc' läuft nicht)"
        fi
        return 0
    fi
    check "$name" "curl -sf $url"
}
http_check "n8n (5678)" "n8n" "http://127.0.0.1:5678/healthz"
http_check "Forgejo (3000)" "forgejo" "http://127.0.0.1:3000/api/healthz"
http_check "Postiz (4007)" "postiz" "http://127.0.0.1:4007"
# Kong has Docker healthcheck (kong health), skip external HTTP check
if docker ps --filter "label=com.docker.compose.service=supabase-kong" -q 2>/dev/null | grep -q .; then
    echo -e "${BLUE}[SKIP]${NC} Supabase Kong (8000) (Docker healthcheck sufficient)"
fi
http_check "Uptime Kuma (3001)" "uptime-kuma" "http://127.0.0.1:3001/api/status"
http_check "Dozzle (8082)" "dozzle" "http://127.0.0.1:8082/healthz"
http_check "Beszel Hub (8090)" "beszel" "http://127.0.0.1:8090/system/health"
http_check "cAdvisor (8080)" "cadvisor" "http://127.0.0.1:8080/healthz"

# 5. Ollama (optional)
echo ""
echo "5. Ollama (lokal, optional):"
if curl -sf http://127.0.0.1:11434/v1/models >/dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC} Ollama API (11434)"
    HEALTHY=$((HEALTHY+1))
else
    warn "Ollama nicht installiert (optional)"
fi

# 6. Tailscale
echo ""
echo "6. Tailscale:"
if tailscale status --json 2>/dev/null | jq -r '.BackendState' 2>/dev/null | grep -q "Running"; then
    echo -e "${GREEN}[OK]${NC} Tailscale verbunden"
    HEALTHY=$((HEALTHY+1))
else
    warn "Tailscale nicht verbunden"
fi

# 7. Disk & Memory
echo ""
echo "7. Ressourcen:"
DISK_USED=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USED" -lt 90 ]; then
    echo -e "${GREEN}[OK]${NC} Disk: ${DISK_USED}% verwendet"
    HEALTHY=$((HEALTHY+1))
else
    echo -e "${RED}[FAIL]${NC} Disk: ${DISK_USED}% verwendet (kritisch)"
    CRITICAL_FAIL=$((CRITICAL_FAIL+1))
fi

MEM_FREE=$(free | awk 'NR==2 {printf "%.0f", $7/$2*100}')
if [ "$MEM_FREE" -gt 10 ]; then
    echo -e "${GREEN}[OK]${NC} Memory: ${MEM_FREE}% frei"
    HEALTHY=$((HEALTHY+1))
else
    warn "Memory: ${MEM_FREE}% frei (wenig)"
fi

echo ""
echo "=== Client Health Summary ==="
echo "healthy:            $HEALTHY"
echo "running (no check): $RUNNING_NO_CHECK"
echo "unhealthy:          $UNHEALTHY"
echo "not started:        $NOT_STARTED  (profile: client-extended)"
echo "critical issues:    $CRITICAL_FAIL"
echo ""
exit $CRITICAL_FAIL