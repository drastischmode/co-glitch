#!/bin/bash
# Validiert Erreichbarkeit aller konfigurierten KI-Modell-Endpunkte
# Exit Code 0 = kritische Checks OK, Warnungen erlaubt
# Kritisch: OpenCode Zen (Default-Provider, funktioniert mit "public" Key)
# Optional: NVIDIA, z.ai, Ollama -> nur Warnung, kein Exit != 0

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

CRITICAL_FAIL=0
WARNINGS=0

check_endpoint() {
    local name="$1"
    local url="$2"
    local auth_header="${3:-}"
    local expected="${4:-200}"
    local critical="${5:-false}"

    if [ -n "$auth_header" ]; then
        code=$(curl -s -o /dev/null -w "%{http_code}" -H "$auth_header" "$url" 2>/dev/null || echo "000")
    else
        code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    fi

    if [ "$code" = "$expected" ]; then
        echo -e "${GREEN}[OK]${NC} $name (HTTP $code)"
        return 0
    else
        if [ "$critical" = "true" ]; then
            echo -e "${RED}[FAIL]${NC} $name (HTTP $code, erwartet $expected) -- KRITISCH"
            CRITICAL_FAIL=1
        else
            echo -e "${YELLOW}[WARN]${NC} $name (HTTP $code, erwartet $expected) -- OPTIONAL"
            WARNINGS=$((WARNINGS+1))
        fi
        return 1
    fi
}

echo "=== Prüfe KI-Modell-Endpunkte ==="
echo ""

# 1. OpenCode Zen (KRITISCH - Default-Provider)
echo "1. OpenCode Zen (Free Tier, Default)..."
check_endpoint "OpenCode Zen" "https://opencode.ai/zen/v1/models" "" "200" "true"
echo ""

# 2. NVIDIA NIM (OPTIONAL)
echo "2. NVIDIA NIM (Optional - Fallback 1)..."
if [ -n "${NVIDIA_API_KEY:-}" ]; then
    check_endpoint "NVIDIA NIM" "https://integrate.api.nvidia.com/v1/models" "Authorization: Bearer ${NVIDIA_API_KEY}" "200" "false"
else
    echo -e "${YELLOW}[WARN]${NC} NVIDIA_API_KEY nicht gesetzt (optional)"
    WARNINGS=$((WARNINGS+1))
fi
echo ""

# 3. z.ai / Zhipu (OPTIONAL)
echo "3. z.ai / Zhipu (Optional - Fallback 2)..."
if [ -n "${ZAI_API_KEY:-}" ]; then
    check_endpoint "z.ai" "https://api.z.ai/api/paas/v4/models" "Authorization: Bearer ${ZAI_API_KEY}" "200" "false"
else
    echo -e "${YELLOW}[WARN]${NC} ZAI_API_KEY nicht gesetzt (optional)"
    WARNINGS=$((WARNINGS+1))
fi
echo ""

# 4. Ollama (OPTIONAL - lokaler Fallback)
echo "4. Ollama (Optional - lokaler Offline-Fallback)..."
if check_endpoint "Ollama" "http://localhost:11434/v1/models" "" "200" "false"; then
    :
else
    echo -e "${YELLOW}[HINT]${NC} make install-ollama  (für lokalen Offline-Fallback)"
fi
echo ""

echo "=== Modell-Validierung abgeschlossen ==="
if [ $CRITICAL_FAIL -gt 0 ]; then
    echo -e "${RED}Kritische Fehler: $CRITICAL_FAIL${NC}"
    exit 1
fi
if [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}Warnungen (optionale Provider): $WARNINGS${NC}"
fi
exit 0