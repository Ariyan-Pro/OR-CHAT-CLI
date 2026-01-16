#!/bin/bash
# Master Test Runner
# Executes all validation tests

set -euo pipefail

echo "========================================"
echo "  ORCHAT COMPREHENSIVE VALIDATION SUITE"
echo "========================================"
echo "Phase: 7.5 Hardening Sprint"
echo "Date: $(date)"
echo "Host: $(hostname)"
echo ""

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

run_test_category() {
    local category="$1"
    local dir="$2"
    
    echo ""
    echo "=== $category Tests ==="
    
    if [ ! -d "$dir" ]; then
        echo "Directory not found: $dir"
        return
    fi
    
    for test_file in "$dir"/*.sh; do
        if [ -f "$test_file" ] && [ -x "$test_file" ]; then
            TEST_NAME=$(basename "$test_file")
            echo ""
            echo "Running: $TEST_NAME"
            echo "----------------------------------------"
            
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            
            if "./$test_file"; then
                echo "✅ $TEST_NAME: PASSED"
                PASSED_TESTS=$((PASSED_TESTS + 1))
            else
                EXIT_CODE=$?
                echo "❌ $TEST_NAME: FAILED (exit code: $EXIT_CODE)"
                FAILED_TESTS=$((FAILED_TESTS + 1))
                
                # Log failure
                echo "$(date): $TEST_NAME failed with exit code $EXIT_CODE" >> reports/failure-log.md
            fi
        fi
    done
}

# Create failure log
mkdir -p reports
echo "# ORCHAT Validation Failures" > reports/failure-log.md
echo "Generated: $(date)" >> reports/failure-log.md
echo "" >> reports/failure-log.md

# Run all test categories
run_test_category "Installation" "install"
run_test_category "Runtime" "runtime"
run_test_category "Performance" "performance"
run_test_category "Observability" "observability"

# Generate final report
echo ""
echo "=== Generating Final Report ==="
./reports/generate-validation-report.sh

echo ""
echo "========================================"
echo "  VALIDATION COMPLETE"
echo "========================================"
echo "Total Tests: $TOTAL_TESTS"
echo "✅ Passed: $PASSED_TESTS"
echo "❌ Failed: $FAILED_TESTS"
echo "⏭️  Skipped: $SKIPPED_TESTS"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo "🎉 ALL TESTS PASSED!"
    echo "Phase 7.5 validation complete."
    exit 0
else
    echo "⚠️  $FAILED_TESTS test(s) failed."
    echo "Check reports/failure-log.md for details."
    exit 1
fi
