#!/bin/bash
# Client Health Check - prüft nur Client-Dienste
# Exit Code 0 = alle OK, 1 = mind. ein FAIL

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

check() {
    local name="$1"
    local cmd="$2"
    if eval "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}[OK]${NC} $name"
        PASS=$((PASS+1))
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $name"
        FAIL=$((FAIL+1))
        return 1
    fi
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
check "UFW aktiv" "sudo ufw status | grep -q 'Status: active'"
check "UFW Forward Policy ACCEPT" "sudo ufw status | grep -q 'DEFAULT_FORWARD_POLICY.*ACCEPT'"

# 3. Container Health (label=co-glitch.tier=client)
echo ""
echo "3. Container (co-glitch.tier=client):"
# Container IDs mit Label filtern
CONTAINERS=$(docker ps --filter "label=co-glitch.tier=client" --format "{{.Names}}" 2>/dev/null || true)
if [ -z "$CONTAINERS" ]; then
    echo -e "${YELLOW}[WARN]${NC} Keine Client-Container gefunden (Stack gestartet?)"
else
    for c in $CONTAINERS; do
        STATUS=$(docker inspect "$c" --format '{{.State.Health.Status}}' 2>/dev/null || echo "no-healthcheck")
        if [ "$STATUS" = "healthy" ]; then
            echo -e "${GREEN}[OK]${NC} $c (healthy)"
            PASS=$((PASS+1))
        elif [ "$STATUS" = "starting" ]; then
            echo -e "${YELLOW}[WAIT]${NC} $c (starting...)"
        elif [ "$STATUS" = "no-healthcheck" ]; then
            RUNNING=$(docker inspect "$c" --format '{{.State.Running}}' 2>/dev/null)
            if [ "$RUNNING" = "true" ]; then
                echo -e "${YELLOW}[WARN]${NC} $c (running, kein healthcheck)"
            else
                echo -e "${RED}[FAIL]${NC} $c (not running)"
                FAIL=$((FAIL+1))
            fi
        else
            echo -e "${RED}[FAIL]${NC} $c ($STATUS)"
            FAIL=$((FAIL+1))
        fi
    done
fi

# 4. HTTP Endpunkte (lokal)
echo ""
echo "4. HTTP Endpunkte:"
check "n8n (5678)" "curl -sf http://localhost:5678/healthz"
check "Forgejo (3000)" "curl -sf http://localhost:3000/api/healthz"
check "Postiz (4007)" "curl -sf http://localhost:4007"
check "Supabase Kong (8000)" "curl -sf http://localhost:8000"
check "Uptime Kuma (3001)" "curl -sf http://localhost:3001/api/status"
check "Dozzle (8082)" "curl -sf http://localhost:8082/healthz"
check "Beszel Hub (8090)" "curl -sf http://localhost:8090/system/health"
check "cAdvisor (8080)" "curl -sf http://localhost:8080/healthz"

# 5. Ollama
echo ""
echo "5. Ollama (lokal):"
check "Ollama API (11434)" "curl -sf http://localhost:11434/v1/models"

# 6. Tailscale
echo ""
echo "6. Tailscale:"
if tailscale status --json 2>/dev/null | jq -r '.BackendState' 2>/dev/null | grep -q "Running"; then
    echo -e "${GREEN}[OK]${NC} Tailscale verbunden"
    PASS=$((PASS+1))
else
    echo -e "${YELLOW}[WARN]${NC} Tailscale nicht verbunden"
fi

# 7. Disk & Memory
echo ""
echo "7. Ressourcen:"
DISK_USED=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USED" -lt 90 ]; then
    echo -e "${GREEN}[OK]${NC} Disk: ${DISK_USED}% verwendet"
    PASS=$((PASS+1))
else
    echo -e "${RED}[FAIL]${NC} Disk: ${DISK_USED}% verwendet (kritisch)"
    FAIL=$((FAIL+1))
fi

MEM_FREE=$(free | awk 'NR==2 {printf "%.0f", $7/$2*100}')
if [ "$MEM_FREE" -gt 10 ]; then
    echo -e "${GREEN}[OK]${NC} Memory: ${MEM_FREE}% frei"
    PASS=$((PASS+1))
else
    echo -e "${YELLOW}[WARN]${NC} Memory: ${MEM_FREE}% frei (wenig)"
fi

echo ""
echo "=== Summary: $PASS OK, $FAIL FAIL ==="
exit $FAIL