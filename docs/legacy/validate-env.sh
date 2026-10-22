#!/bin/bash
# Validiert .env auf Vollständigkeit

set -euo pipefail

ENV_FILE=".env"
REQUIRED_VARS=(
    "OPENCODE_API_KEY"
    "NVIDIA_API_KEY"
    "ZAI_API_KEY"
    "SUPABASE_DB_PASS"
    "POSTIZ_JWT_SECRET"
    "FORGEJO_DB_PASS"
    "TEMPORAL_DB_PASS"
    "POSTIZ_DB_PASS"
    "SUPABASE_ANON_KEY"
    "SUPABASE_SERVICE_KEY"
    "SUPABASE_JWT_SECRET"
    "SUPABASE_DB_URL"
    "CADDY_AUTH_HASH_KUMA"
    "CADDY_AUTH_HASH_BESZEL"
    "CADDY_AUTH_HASH_DOZZLE"
    "CADDY_AUTH_HASH_CADVISOR"
    "CADDY_AUTH_HASH_N8N"
)

if [ ! -f "$ENV_FILE" ]; then
    echo "FEHLER: .env nicht gefunden. Führe 'make gen-secrets' aus."
    exit 1
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

MISSING=0
PLACEHOLDERS=0

for var in "${REQUIRED_VARS[@]}"; do
    value="${!var}"
    if [ -z "$value" ]; then
        echo "FEHLEND: $var"
        MISSING=$((MISSING + 1))
    elif [[ "$value" == GENERATE_ME_* ]]; then
        echo "PLATZHALTER: $var (nicht generiert)"
        PLACEHOLDERS=$((PLACEHOLDERS + 1))
    fi
done

if [ $MISSING -gt 0 ] || [ $PLACEHOLDERS -gt 0 ]; then
    echo ""
    echo "Validierung FEHLGESCHLAGEN: $MISSING fehlend, $PLACEHOLDERS Platzhalter"
    exit 1
else
    echo "✅ .env Validierung erfolgreich: Alle ${#REQUIRED_VARS[@]} Variablen gesetzt"
fi