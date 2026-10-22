#!/bin/bash
# Validiert Erreichbarkeit aller konfigurierten KI-Modell-Endpunkte

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_endpoint() {
    local name="$1"
    local url="$2"
    local auth_header="${3:-}"
    local expected="${4:-200}"

    if [ -n "$auth_header" ]; then
        code=$(curl -s -o /dev/null -w "%{http_code}" -H "$auth_header" "$url" 2>/dev/null || echo "000")
    else
        code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    fi

    if [ "$code" = "$expected" ]; then
        echo -e "${GREEN}[OK]${NC} $name (HTTP $code)"
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $name (HTTP $code, erwartet $expected)"
        return 1
    fi
}

echo "=== Prüfe KI-Modell-Endpunkte ==="
echo ""

FAIL=0

# 1. OpenCode Zen
echo "1. OpenCode Zen (Free Tier)..."
if ! check_endpoint "OpenCode Zen" "https://opencode.ai/zen/v1/models" "" "200"; then
    FAIL=1
fi
echo ""

# 2. NVIDIA NIM
echo "2. NVIDIA NIM..."
if [ -n "${NVIDIA_API_KEY:-}" ]; then
    if ! check_endpoint "NVIDIA NIM" "https://integrate.api.nvidia.com/v1/models" "Authorization: Bearer ${NVIDIA_API_KEY}" "200"; then
        FAIL=1
    fi
else
    echo -e "${YELLOW}[SKIP]${NC} NVIDIA_API_KEY nicht gesetzt"
fi
echo ""

# 3. z.ai / Zhipu
echo "3. z.ai / Zhipu..."
if [ -n "${ZAI_API_KEY:-}" ]; then
    if ! check_endpoint "z.ai" "https://api.z.ai/api/paas/v4/models" "Authorization: Bearer ${ZAI_API_KEY}" "200"; then
        FAIL=1
    fi
else
    echo -e "${YELLOW}[SKIP]${NC} ZAI_API_KEY nicht gesetzt"
fi
echo ""

# 4. Ollama (optional - Faellt zurueck auf Cloud-Provider)
echo "4. Ollama (lokal, optional)..."
if ! check_endpoint "Ollama" "http://localhost:11434/v1/models" "" "200"; then
    echo -e "${YELLOW}[SKIP]${NC} Ollama nicht installiert (optional) -> make install-ollama"
    echo -e "${YELLOW}[HINT]${NC} Ohne Ollama wird der lokale Offline-Fallback nicht genutzt"
fi
echo ""

echo "=== Modell-Validierung abgeschlossen ==="
exit $FAIL