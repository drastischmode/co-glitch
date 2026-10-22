#!/bin/bash
# Kong Initialisierung für Supabase
# Erstellt Consumers und Credentials via Kong Admin API
# Wird als entrypoint in kong container oder manuell nach Start ausgeführt

set -euo pipefail

KONG_ADMIN="http://localhost:8001"
MAX_RETRIES=30
RETRY_INTERVAL=2

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# Warten bis Kong Admin API bereit ist
log "Warte auf Kong Admin API..."
for i in $(seq 1 $MAX_RETRIES); do
    if curl -sf "$KONG_ADMIN/status" >/dev/null 2>&1; then
        log "Kong Admin API bereit"
        break
    fi
    if [ $i -eq $MAX_RETRIES ]; then
        log "FEHLER: Kong Admin API nicht erreichbar nach $MAX_RETRIES Versuchen"
        exit 1
    fi
    sleep $RETRY_INTERVAL
done

# Environment Variablen prüfen
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY nicht gesetzt}"
: "${SUPABASE_SERVICE_KEY:?SUPABASE_SERVICE_KEY nicht gesetzt}"

# Consumer: anon
log "Erstelle/aktualisiere Consumer 'anon'..."
CONSUMER_EXISTS=$(curl -sf "$KONG_ADMIN/consumers/anon" 2>/dev/null || echo "")
if [ -z "$CONSUMER_EXISTS" ]; then
    curl -s -X POST "$KONG_ADMIN/consumers" \
        -d "username=anon" \
        -d "custom_id=anon" >/dev/null
    log "Consumer 'anon' erstellt"
else
    log "Consumer 'anon' existiert bereits"
fi

# Credential für anon
CRED_EXISTS=$(curl -sf "$KONG_ADMIN/consumers/anon/key-auth" 2>/dev/null | jq -r '.data[0].key // empty' 2>/dev/null || echo "")
if [ -z "$CRED_EXISTS" ] || [ "$CRED_EXISTS" != "$SUPABASE_ANON_KEY" ]; then
    curl -s -X POST "$KONG_ADMIN/consumers/anon/key-auth" \
        -d "key=$SUPABASE_ANON_KEY" >/dev/null
    log "Credential für 'anon' gesetzt"
else
    log "Credential für 'anon' bereits korrekt"
fi

# Consumer: service_role
log "Erstelle/aktualisiere Consumer 'service_role'..."
CONSUMER_EXISTS=$(curl -sf "$KONG_ADMIN/consumers/service_role" 2>/dev/null || echo "")
if [ -z "$CONSUMER_EXISTS" ]; then
    curl -s -X POST "$KONG_ADMIN/consumers" \
        -d "username=service_role" \
        -d "custom_id=service_role" >/dev/null
    log "Consumer 'service_role' erstellt"
else
    log "Consumer 'service_role' existiert bereits"
fi

# Credential für service_role
CRED_EXISTS=$(curl -sf "$KONG_ADMIN/consumers/service_role/key-auth" 2>/dev/null | jq -r '.data[0].key // empty' 2>/dev/null || echo "")
if [ -z "$CRED_EXISTS" ] || [ "$CRED_EXISTS" != "$SUPABASE_SERVICE_KEY" ]; then
    curl -s -X POST "$KONG_ADMIN/consumers/service_role/key-auth" \
        -d "key=$SUPABASE_SERVICE_KEY" >/dev/null
    log "Credential für 'service_role' gesetzt"
else
    log "Credential für 'service_role' bereits korrekt"
fi

# Key-Auth Plugin global aktivieren (falls nicht via declarative config)
PLUGIN_EXISTS=$(curl -sf "$KONG_ADMIN/plugins" 2>/dev/null | jq -r '.data[] | select(.name=="key-auth") | .id' 2>/dev/null | head -1 || echo "")
if [ -z "$PLUGIN_EXISTS" ]; then
    curl -s -X POST "$KONG_ADMIN/plugins" \
        -d "name=key-auth" \
        -d "config.key_names[]=apikey" \
        -d "config.hide_credentials=true" >/dev/null
    log "Key-Auth Plugin global aktiviert"
else
    log "Key-Auth Plugin bereits aktiv"
fi

# CORS Plugin global (für alle Routes)
CORS_EXISTS=$(curl -sf "$KONG_ADMIN/plugins" 2>/dev/null | jq -r '.data[] | select(.name=="cors") | .id' 2>/dev/null | head -1 || echo "")
if [ -z "$CORS_EXISTS" ]; then
    curl -s -X POST "$KONG_ADMIN/plugins" \
        -d "name=cors" \
        -d "config.origins[]=*" \
        -d "config.methods[]=GET" \
        -d "config.methods[]=POST" \
        -d "config.methods[]=PUT" \
        -d "config.methods[]=DELETE" \
        -d "config.methods[]=PATCH" \
        -d "config.methods[]=OPTIONS" \
        -d "config.headers[]=Accept" \
        -d "config.headers[]=Authorization" \
        -d "config.headers[]=Content-Type" \
        -d "config.headers[]=apikey" \
        -d "config.headers[]=Prefer" \
        -d "config.exposed_headers[]=Content-Range" \
        -d "config.exposed_headers[]=X-Total-Count" \
        -d "config.credentials=true" \
        -d "config.max_age=3600" >/dev/null
    log "CORS Plugin global aktiviert"
else
    log "CORS Plugin bereits aktiv"
fi

log "Kong Initialisierung abgeschlossen"