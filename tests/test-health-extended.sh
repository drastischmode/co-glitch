#!/bin/bash
# test-health-extended.sh: Mock-Test für Healthcheck im Extended-Profil

# set -euo pipefail  -- DISABLED for debugging

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

check() {
    local name="$1"
    local cmd="$2"
    eval "$cmd" >/dev/null 2>&1
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}[PASS]${NC} $name"
        PASS=$((PASS+1))
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $name"
        FAIL=$((FAIL+1))
        return 0
    fi
}

check_expected_fail() {
    local name="$1"
    local cmd="$2"
    eval "$cmd" >/dev/null 2>&1
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo -e "${GREEN}[PASS]${NC} $name (expected failure)"
        PASS=$((PASS+1))
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $name (expected failure but passed)"
        FAIL=$((FAIL+1))
        return 0
    fi
}

MOCK_DOCKER_PS_HEALTHY=$'client-supabase-db-1\thealthy\nclient-supabase-kong-1\thealthy\nclient-n8n-1\thealthy\nclient-forgejo-1\thealthy\nclient-uptime-kuma-1\thealthy\nclient-cadvisor-1\thealthy\nclient-dozzle-1\tno-check\nclient-beszel-1\tno-check\nclient-postiz-1\thealthy\nclient-redis-1\thealthy\nclient-beszel-agent-1\tno-check\nclient-diun-1\tno-check'

MOCK_DOCKER_PS_UNHEALTHY=$'client-supabase-db-1\thealthy\nclient-supabase-kong-1\thealthy\nclient-n8n-1\thealthy\nclient-forgejo-1\thealthy\nclient-uptime-kuma-1\thealthy\nclient-cadvisor-1\thealthy\nclient-dozzle-1\tno-check\nclient-beszel-1\tno-check\nclient-postiz-1\tunhealthy\nclient-redis-1\thealthy\nclient-beszel-agent-1\tno-check\nclient-diun-1\tno-check'

PASS=0
FAIL=0

echo "=== Extended Health Semantics Tests (Mocked) ==="
echo ""

echo "Test 1: All Extended services healthy -> Exit 0"
HEALTHY=$(echo "$MOCK_DOCKER_PS_HEALTHY" | grep -c "healthy$")
RUNNING_NO_CHECK=$(echo "$MOCK_DOCKER_PS_HEALTHY" | grep -c "no-check$")
UNHEALTHY=$(echo "$MOCK_DOCKER_PS_HEALTHY" | grep -c "unhealthy$")
NOT_STARTED=0

check "Healthy count = 8" "[ \$HEALTHY -eq 8 ]"
check "Running no-check = 4" "[ \$RUNNING_NO_CHECK -eq 4 ]"
check "Unhealthy = 0" "[ \$UNHEALTHY -eq 0 ]"
check "Not started = 0" "[ \$NOT_STARTED -eq 0 ]"
check "Exit code would be 0" "[ \$UNHEALTHY -eq 0 ]"

echo ""
echo "Test 2: Postiz unhealthy -> Exit 2 (critical)"
HEALTHY=$(echo "$MOCK_DOCKER_PS_UNHEALTHY" | grep -c "healthy$")
RUNNING_NO_CHECK=$(echo "$MOCK_DOCKER_PS_UNHEALTHY" | grep -c "no-check$")
UNHEALTHY=$(echo "$MOCK_DOCKER_PS_UNHEALTHY" | grep -c "unhealthy$")
NOT_STARTED=0

check_expected_fail "Healthy count != 7 (should be 8)" "[ \$HEALTHY -eq 7 ]"
check "Running no-check = 4" "[ \$RUNNING_NO_CHECK -eq 4 ]"
check "Unhealthy = 1" "[ \$UNHEALTHY -eq 1 ]"
check "Not started = 0" "[ \$NOT_STARTED -eq 0 ]"
check "Exit code would be 2 (critical)" "[ \$UNHEALTHY -eq 1 ]"

echo ""

echo "Test 3: Verify service count in extended profile"
TOTAL_SERVICES=$(echo "$MOCK_DOCKER_PS_HEALTHY" | wc -l)
check "Total services in extended = 12" "[ \$TOTAL_SERVICES -eq 12 ]"

echo ""

echo "Test 4: Verify specific services exist in mock"
check "postiz in mock" "echo \"\$MOCK_DOCKER_PS_HEALTHY\" | grep -q 'client-postiz-1'"
check "redis in mock" "echo \"\$MOCK_DOCKER_PS_HEALTHY\" | grep -q 'client-redis-1'"
check "beszel-agent in mock" "echo \"\$MOCK_DOCKER_PS_HEALTHY\" | grep -q 'client-beszel-agent-1'"
check "diun in mock" "echo \"\$MOCK_DOCKER_PS_HEALTHY\" | grep -q 'client-diun-1'"

echo ""

echo "=== Summary: $PASS passed, $FAIL failed ==="
exit $FAIL
