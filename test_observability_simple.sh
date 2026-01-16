#!/bin/bash
echo "=== SIMPLE OBSERVABILITY TEST ==="
echo "Testing ORCHAT with basic observability..."
echo ""

# Test that ORCHAT is installed
echo "1. Checking ORCHAT installation..."
which orchat
echo "Exit code: $?"
echo ""

# Test basic help
echo "2. Testing help command..."
orchat --help | head -10
echo ""

# Test a simple query
echo "3. Testing simple query (no-stream)..."
orchat "Test from installed package" --no-stream 2>&1 | head -5
echo ""

echo "✅ Basic observability test complete"
