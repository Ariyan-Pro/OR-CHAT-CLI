#!/bin/bash
# Concurrent Requests Stress Test
# Tests system under concurrent load

set -euo pipefail

echo "=== Concurrent Requests Stress Test ==="
echo ""

# Create test prompts
PROMPTS=(
    "Hello, world!"
    "What is the capital of France?"
    "Explain quantum computing in simple terms"
    "Write a short poem about technology"
    "What are the benefits of renewable energy?"
)

# Number of concurrent requests
CONCURRENT=3
TIMEOUT=30

echo "Testing $CONCURRENT concurrent requests with $TIMEOUT second timeout..."

# Run concurrent requests
for i in $(seq 1 $CONCURRENT); do
    prompt="${PROMPTS[$((i % ${#PROMPTS[@]}))]}"
    echo "  Starting request $i: '$prompt'"
    timeout $TIMEOUT orchat "$prompt" >/dev/null 2>&1 &
    PIDS[$i]=$!
done

# Wait for all processes
FAILED=0
for pid in "${PIDS[@]}"; do
    if wait $pid; then
        echo "  ✅ Process $pid completed successfully"
    else
        echo "  ❌ Process $pid failed or timed out"
        FAILED=$((FAILED + 1))
    fi
done

# Report results
if [ $FAILED -eq 0 ]; then
    echo "✅ All $CONCURRENT concurrent requests completed successfully"
else
    echo "❌ $FAILED out of $CONCURRENT requests failed"
    exit 1
fi
