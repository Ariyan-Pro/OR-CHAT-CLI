#!/bin/bash
# Quick Validation Test
# Runs essential tests quickly

set -euo pipefail

echo "=== ORCHAT QUICK VALIDATION ==="
echo "Date: $(date)"
echo ""

# Test 1: Basic functionality
echo "1. Testing basic ORCHAT functionality..."
if orchat --version >/dev/null 2>&1; then
    echo "✅ ORCHAT version check passed"
else
    echo "❌ ORCHAT version check failed"
    exit 1
fi

# Test 2: API key check
echo ""
echo "2. Checking API key configuration..."
if [ -f ~/.config/orchat/secure_key.sh ]; then
    echo "✅ Secure key file exists"
    if ~/.config/orchat/secure_key.sh validate >/dev/null 2>&1; then
        echo "✅ API key is valid"
    else
        echo "⚠️  API key validation issue"
    fi
else
    echo "⚠️  Secure key file not found"
fi

# Test 3: Production wrapper
echo ""
echo "3. Testing production wrapper..."
OUTPUT=$(~/.local/bin/orchat-prod --version 2>&1 | head -1)
if [[ "$OUTPUT" == *"ORCHAT"* ]] || [[ "$OUTPUT" == *"version"* ]]; then
    echo "✅ Production wrapper working"
else
    echo "⚠️  Production wrapper output: $OUTPUT"
fi

# Test 4: Validation test structure
echo ""
echo "4. Checking validation framework..."
if [ -f ./run-all.sh ]; then
    echo "✅ Master test runner exists"
    TEST_COUNT=$(find install runtime performance observability -name "*.sh" -type f 2>/dev/null | wc -l)
    echo "   Found $TEST_COUNT test files"
else
    echo "❌ Missing master test runner"
fi

echo ""
echo "=== QUICK VALIDATION COMPLETE ==="
echo ""
echo "For comprehensive testing, run: ./run-all.sh"
echo "For detailed reports, check: reports/"
