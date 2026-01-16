#!/bin/bash
# Test ORCHAT Advanced Features
# Workstream 3 Testing

echo "=== TESTING ADVANCED FEATURES ==="
echo ""

# Load the modules
source ./session_manager.sh
source ./context_optimizer.sh

echo "=== TEST 1: SESSION MANAGEMENT ==="
echo "Creating test session..."
SESSION_ID=$(create_session "openai/gpt-4" 0.8)
echo "Session created: $SESSION_ID"
echo ""

echo "Adding messages to session..."
add_to_session "$SESSION_ID" "user" "Hello, this is a test message"
add_to_session "$SESSION_ID" "assistant" "Hello! I'm here to help with your test."
add_to_session "$SESSION_ID" "user" "Testing session persistence"
echo ""

echo "Listing sessions..."
list_sessions
echo ""

echo "Session statistics..."
session_stats
echo ""

echo "=== TEST 2: CONTEXT OPTIMIZATION ==="
echo "Creating test context..."
TEST_CONTEXT='[
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user", "content": "'$(printf '%.0sx' {1..1000})'"},
    {"role": "assistant", "content": "'$(printf '%.0sx' {1..800})'"},
    {"role": "user", "content": "'$(printf '%.0sx' {1..1200})'"},
    {"role": "assistant", "content": "'$(printf '%.0sx' {1..900})'"},
    {"role": "user", "content": "'$(printf '%.0sx' {1..1100})'"}
]'

echo "Analyzing context..."
analyze_context "$TEST_CONTEXT"
echo ""

echo "Optimizing context..."
OPTIMIZED=$(optimize_context "$TEST_CONTEXT" 5000)
echo "Optimization complete"
echo ""

echo "=== TEST 3: BATCH PROCESSING ==="
echo "Creating test batch directory..."
mkdir -p test_batch/input test_batch/output
for i in {1..3}; do
    echo '{"messages": [{"role": "user", "content": "Test message '$i'"}]}' > "test_batch/input/context_$i.json"
done

echo "Batch directory created with 3 test files"
ls -la test_batch/input/
echo ""

echo "✅ Advanced features test completed"
echo ""
echo "Cleanup..."
rm -rf test_batch
cleanup_sessions
