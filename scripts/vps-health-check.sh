#!/bin/bash
# VPS Health Check - prüft VPS-spezifische Dienste
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

echo "=== VPS Health Check ==="
echo ""

# 1. Docker Daemon
echo "1. Docker Daemon:"
check "Docker läuft" "systemctl is-active --quiet docker"
check "Docker erreichbar" "docker info --format '{{.ServerVersion}}' >/dev/null"

# 2. UFW
echo ""
echo "2. Firewall:"
check "UFW aktiv" "ufw status | grep -q 'Status: active'"
check "UFW Forward Policy ACCEPT" "ufw status | grep -q 'DEFAULT_FORWARD_POLICY.*ACCEPT'"
check "Port 8443-8447 offen" "ufw status | grep -q '8443.*ALLOW' && ufw status | grep -q '8447.*ALLOW'"

# 3. VPS Container (label=co-glitch.tier=vps)
echo ""
echo "3. VPS Container (co-glitch.tier=vps):"
CONTAINERS=$(docker ps --filter "label=co-glitch.tier=vps" --format "{{.Names}}" 2>/dev/null || true)
if [ -z "$CONTAINERS" ]; then
    echo -e "${YELLOW}[WARN]${NC} Keine VPS-Container gefunden (make up-vps ausgeführt?)"
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

# 4. Caddy Proxy Ports
echo ""
echo "4. Caddy Proxy (Tailnet):"
for port in 8443 8444 8445 8446 8447; do
    check "Port $port LISTEN" "ss -tlnp | grep -q ':$port '"
done

# 5. Tailscale
echo ""
echo "5. Tailscale:"
if tailscale status --json 2>/dev/null | jq -r '.BackendState' 2>/dev/null | grep -q "Running"; then
    echo -e "${GREEN}[OK]${NC} Tailscale verbunden"
    TAIL_IP=$(tailscale status --json 2>/dev/null | jq -r '.Self.TailscaleIPs[0]' 2>/dev/null)
    echo "       Tailnet IP: $TAIL_IP"
    PASS=$((PASS+1))
else
    echo -e "${RED}[FAIL]${NC} Tailscale nicht verbunden"
    FAIL=$((FAIL+1))
fi

# 6. Keepalive Service
echo ""
echo "6. Keepalive Service:"
check "Keepalive aktiv" "systemctl is-active --quiet keepalive"

# 7. Ressourcen
echo ""
echo "7. Ressourcen:"
DISK_USED=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USED" -lt 90 ]; then
    echo -e "${GREEN}[OK]${NC} Disk: ${DISK_USED}% verwendet"
    PASS=$((PASS+1))
else
    echo -e "${RED}[FAIL]${NC} Disk: ${DISK_USED}% verwendet"
    FAIL=$((FAIL+1))
fi

MEM_FREE=$(free | awk 'NR==2 {printf "%.0f", $7/$2*100}')
if [ "$MEM_FREE" -gt 10 ]; then
    echo -e "${GREEN}[OK]${NC} Memory: ${MEM_FREE}% frei"
    PASS=$((PASS+1))
else
    echo -e "${YELLOW}[WARN]${NC} Memory: ${MEM_FREE}% frei"
fi

echo ""
echo "=== Summary: $PASS OK, $FAIL FAIL ==="
exit $FAIL