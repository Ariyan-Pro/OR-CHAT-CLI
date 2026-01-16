#!/bin/bash
# Input Validation Test
# Tests various edge cases for input handling

set -euo pipefail

echo "=== Input Validation Test ==="
echo ""

# Test cases: (input, expected_exit_code)
TEST_CASES=(
    "" "2"            # Empty input should fail
    "x" "0"           # Single character should work
    "test" "0"        # Normal input should work
)

echo "Running input validation tests..."
echo ""

for ((i=0; i<${#TEST_CASES[@]}; i+=2)); do
    INPUT="${TEST_CASES[$i]}"
    EXPECTED="${TEST_CASES[$((i+1))]}"
    
    echo "Test: '$INPUT' (expecting exit code $EXPECTED)"
    
    if [ -z "$INPUT" ]; then
        orchat 2>&1 | grep -q "No prompt provided" && ACTUAL="2" || ACTUAL="0"
    else
        orchat "$INPUT" >/dev/null 2>&1
        ACTUAL="$?"
    fi
    
    if [ "$ACTUAL" = "$EXPECTED" ]; then
        echo "  ✅ PASS"
    else
        echo "  ❌ FAIL (got exit code $ACTUAL)"
        exit 1
    fi
done

echo "✅ Input validation test PASSED"
