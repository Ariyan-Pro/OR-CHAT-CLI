#!/usr/bin/env bash
# Test ORCHAT deployment

echo "=== ORCHAT DEPLOYMENT TEST ==="
echo ""

# Test 1: Binary works
echo "1. Testing binary..."
if command -v orchat >/dev/null 2>&1; then
    echo "   ✅ orchat command available"
else
    echo "   ❌ orchat command not found"
fi

# Test 2: Basic help
echo "2. Testing help command..."
if orchat --help 2>&1 | grep -q "ORCHAT"; then
    echo "   ✅ Help command works"
else
    echo "   ❌ Help command failed"
fi

# Test 3: Enterprise commands
echo "3. Testing enterprise mode..."
if orchat enterprise 2>&1 | grep -q "ENTERPRISE MODE"; then
    echo "   ✅ Enterprise mode works"
else
    echo "   ❌ Enterprise mode failed"
fi

# Test 4: Health check
echo "4. Testing health check..."
if orchat health-check 2>&1 | grep -q "HEALTH CHECK"; then
    echo "   ✅ Health check works"
else
    echo "   ❌ Health check failed"
fi

echo ""
echo "=== DEPLOYMENT TEST COMPLETE ==="
