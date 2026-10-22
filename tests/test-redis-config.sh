#!/bin/bash
# test-redis-config.sh: Prüft Redis-Konfiguration im Extended-Profil

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
        echo -e "${GREEN}[PASS]${NC} $name"
        PASS=$((PASS+1))
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $name"
        FAIL=$((FAIL+1))
        return 1
    fi
}

# Use source YAML file since docker compose config doesn't show healthcheck when REDIS_PASSWORD is empty
COMPOSE_FILE="docker/client/docker-compose.yml"

echo "=== Redis Config Tests ==="
echo ""

# 1. Redis service exists in extended profile
check "Redis service defined" "grep -q '^  redis:' $COMPOSE_FILE"

# 2. Redis has healthcheck (check source YAML - need -A40 to capture healthcheck)
check "Redis has healthcheck" "grep -A40 '^  redis:' $COMPOSE_FILE | grep -q 'healthcheck:'"

# 3. Redis depends on condition service_healthy in Postiz
check "Postiz depends_on redis service_healthy" "grep -A40 '^  postiz:' $COMPOSE_FILE | grep -A10 'depends_on:' | grep -q 'redis:' && grep -A40 '^  postiz:' $COMPOSE_FILE | grep -A10 'depends_on:' | grep -q 'condition: service_healthy'"

# 4. Postiz has REDIS_URL environment variable
check "Postiz has REDIS_URL" "grep -A40 '^  postiz:' $COMPOSE_FILE | grep -q 'REDIS_URL=redis://'"

# 5. Postiz depends_on supabase-db service_healthy
check "Postiz depends_on supabase-db service_healthy" "grep -A40 '^  postiz:' $COMPOSE_FILE | grep -A10 'depends_on:' | grep -q 'supabase-db:' && grep -A40 '^  postiz:' $COMPOSE_FILE | grep -A10 'depends_on:' | grep -q 'condition: service_healthy'"

# 6. Redis volume defined
check "Redis volume defined" "grep -q 'redis_data:' $COMPOSE_FILE"

# 7. Redis networks includes net-backend
check "Redis connected to net-backend" "grep -A40 '^  redis:' $COMPOSE_FILE | grep -q 'net-backend'"

echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
exit $FAIL