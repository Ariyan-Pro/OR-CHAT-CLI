#!/bin/bash
# Unit Test: Session Manager
# Workstream 4 Testing Suite

set -e

echo "=== SESSION MANAGER UNIT TEST ==="
echo ""

# Test 1: Session creation
echo "Test 1: Session Creation"
SESSION_ID=$(create_session "openai/gpt-4" 0.8 2>/dev/null)
if [[ -n "$SESSION_ID" ]]; then
    echo "✅ Session created: $SESSION_ID"
else
    echo "❌ Session creation failed"
    exit 1
fi
echo ""

# Test 2: Session file exists
echo "Test 2: Session File Existence"
SESSION_FILE="$HOME/.orchat/sessions/$SESSION_ID.json"
if [[ -f "$SESSION_FILE" ]]; then
    echo "✅ Session file exists: $SESSION_FILE"
else
    echo "❌ Session file missing"
    exit 1
fi
echo ""

# Test 3: Add message to session
echo "Test 3: Add Message to Session"
if add_to_session "$SESSION_ID" "user" "Test message" 2>/dev/null; then
    echo "✅ Message added to session"
else
    echo "❌ Failed to add message"
    exit 1
fi
echo ""

# Test 4: List sessions
echo "Test 4: List Sessions"
if list_sessions 2>&1 | grep -q "$SESSION_ID"; then
    echo "✅ Session appears in list"
else
    echo "❌ Session not in list"
    exit 1
fi
echo ""

# Test 5: Session statistics
echo "Test 5: Session Statistics"
if session_stats 2>&1 | grep -q "Total Sessions"; then
    echo "✅ Session statistics work"
else
    echo "❌ Session statistics failed"
    exit 1
fi
echo ""

# Cleanup
echo "Cleaning up test session..."
cleanup_sessions 2>/dev/null || true
echo ""

echo "=== SESSION MANAGER TESTS: ALL PASS ==="
