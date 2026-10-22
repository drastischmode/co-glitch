#!/bin/bash
# run.sh: Test runner for co-glitch

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

run_test() {
    local name="$1"
    local script="$2"
    echo -e "${YELLOW}>>> Running $name...${NC}"
    if bash "$script"; then
        echo -e "${GREEN}>>> $name PASSED${NC}"
        return 0
    else
        echo -e "${RED}>>> $name FAILED${NC}"
        return 1
    fi
}

echo "=== co-glitch Test Suite ==="
echo ""

PASSED=0
FAILED=0

# Test 1: Redis Config
if run_test "Redis Config" "tests/test-redis-config.sh"; then
    PASSED=$((PASSED+1))
else
    FAILED=$((FAILED+1))
fi

echo ""

# Test 2: Health Extended Semantics
if run_test "Health Extended Semantics" "tests/test-health-extended.sh"; then
    PASSED=$((PASSED+1))
else
    FAILED=$((FAILED+1))
fi

echo ""
echo "=== Test Suite Summary ==="
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"

if [ $FAILED -gt 0 ]; then
    exit 1
fi
exit 0