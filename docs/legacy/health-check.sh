#!/bin/bash
# System Health Check für co-glitch
# Wird von make health-check aufgerufen

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

echo "=== Health Check ==="
echo ""

# 1. Docker Daemon
echo "1. Docker Daemon:"
if docker info --format '  Version: {{.ServerVersion}}' 2>/dev/null; then
    log_info "Docker erreichbar"
else
    log_error "Docker nicht erreichbar"
    exit 1
fi
echo ""

# 2. Container Status
echo "2. Container Status:"
docker ps --format '  {{.Names}}: {{.Status}}' | sort
echo ""

# 3. UFW Status
echo "3. UFW Status:"
if sudo ufw status | grep -q "Status: active"; then
    log_info "UFW: Aktiv"
else
    log_warn "UFW: INAKTIV!"
fi
if sudo ufw status | grep -q "DEFAULT_FORWARD_POLICY.*ACCEPT"; then
    log_info "Forward Policy: ACCEPT"
else
    log_warn "Forward Policy: NICHT ACCEPT (Docker Ports blockiert!)"
fi
echo ""

# 4. Tailscale
echo "4. Tailscale:"
if tailscale status --json 2>/dev/null | jq -r '"  Backend: " + .BackendState + ", Tailscale IP: " + .Self.TailscaleIPs[0]' 2>/dev/null; then
    :
else
    log_warn "Nicht verbunden oder tailscale nicht installiert"
fi
echo ""

# 5. Caddy Reverse Proxy (Ports 8443-8447)
echo "5. Caddy Reverse Proxy (Ports 8443-8447):"
for port in 8443 8444 8445 8446 8447; do
    if sudo ss -tlnp | grep -q ":$port "; then
        log_info "Port $port: LISTEN"
    else
        log_warn "Port $port: NICHT erreichbar"
    fi
done
echo ""

# 6. DNS Resolution (Tailnet)
echo "6. DNS Resolution (Tailnet):"
if getent hosts "$(hostname)" 2>/dev/null | head -1 | awk '{print "  " $1 " -> " $2}'; then
    :
else
    log_warn "Kein Hostname-Eintrag"
fi
echo ""

# 7. Disk Space
echo "7. Disk Space:"
df -h / | awk 'NR==2 {print "  Root: " $3 " / " $2 " (" $5 " verwendet)"}'
echo ""

# 8. Memory
echo "8. Memory:"
free -h | awk 'NR==2 {print "  RAM: " $3 " / " $2}'
echo ""

# 9. Docker Volumes
echo "9. Docker Volumes:"
docker system df --format "table {{.Type}}\t{{.TotalCount}}\t{{.Size}}\t{{.Reclaimable}}"
echo ""

echo "=== Health Check abgeschlossen ==="