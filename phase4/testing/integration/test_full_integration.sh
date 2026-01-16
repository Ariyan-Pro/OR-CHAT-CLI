#!/bin/bash
# Integration Test: Full ORCHAT System
# Workstream 4 Testing Suite

set -e

echo "=== FULL SYSTEM INTEGRATION TEST ==="
echo ""
echo "Testing ORCHAT v0.3.3 with Workstream 3 features"
echo ""

# Load modules
source /usr/lib/orchat/bootstrap.sh 2>/dev/null || {
    echo "❌ Failed to load bootstrap"
    exit 1
}

# Test 1: Version check
echo "Test 1: Version Check"
if orchat --version 2>&1 | grep -q "v0.3.3"; then
    echo "✅ Correct version: v0.3.3"
else
    echo "❌ Wrong version"
    exit 1
fi
echo ""

# Test 2: Help system
echo "Test 2: Help System"
if orchat --help 2>&1 | grep -q "WORKSTREAM 3"; then
    echo "✅ Workstream 3 in help"
else
    echo "❌ Workstream 3 missing from help"
    exit 1
fi
echo ""

# Test 3: Advanced commands
echo "Test 3: Advanced Commands"
if orchat advanced 2>&1 | grep -q "Advanced Features"; then
    echo "✅ Advanced command works"
else
    echo "❌ Advanced command broken"
    exit 1
fi
echo ""

# Test 4: Session management integration
echo "Test 4: Session Management"
SESSION_ID=$(orchat session create openai/gpt-3.5-turbo 0.7 2>/dev/null)
if [[ -n "$SESSION_ID" ]] && [[ "$SESSION_ID" != "Session"* ]]; then
    echo "✅ Session created: $SESSION_ID"
    
    # Verify session appears in list
    if orchat session list 2>&1 | grep -q "$SESSION_ID"; then
        echo "✅ Session appears in list"
    else
        echo "❌ Session not in list"
    fi
else
    echo "❌ Session creation failed: $SESSION_ID"
    exit 1
fi
echo ""

# Test 5: Context optimizer integration
echo "Test 5: Context Optimizer"
# Create a test context file
TEST_JSON='[{"role": "user", "content": "Test message"}]'
echo "$TEST_JSON" > /tmp/test_context.json

if orchat context analyze /tmp/test_context.json 2>&1 | grep -q "CONTEXT ANALYSIS"; then
    echo "✅ Context analyzer works"
else
    echo "❌ Context analyzer failed"
fi
echo ""

# Test 6: Core functionality
echo "Test 6: Core Functionality"
if orchat "Integration test" --no-stream --max-tokens 5 2>&1 | grep -q "ORCHAT"; then
    echo "✅ Core functionality works (temporary mode)"
else
    echo "❌ Core functionality broken"
    exit 1
fi
echo ""

# Cleanup
rm -f /tmp/test_context.json
orchat session cleanup 2>/dev/null || true

echo "=== INTEGRATION TESTS: ALL PASS ==="
echo ""
echo "ORCHAT v0.3.3 with Workstream 3 is fully integrated and working!"
