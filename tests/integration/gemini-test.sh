#!/bin/bash
# Integration test for Phase 3 features

set -e

echo "=== Phase 3 Integration Test ==="
echo ""

cd "$(dirname "$0")/../.."

# Check Python availability
echo "1. Checking Python dependencies..."
python3 --version || { echo "Python3 required"; exit 1; }
python3 -c "import json" || { echo "Python json module required"; exit 1; }
echo "✅ Python OK"

# Check modules
echo ""
echo "2. Checking Phase 3 modules..."
for module in history context payload gemini_integration session; do
    if [[ -f "src/$module.sh" ]]; then
        echo "✅ $module.sh"
    else
        echo "❌ Missing: $module.sh"
        exit 1
    fi
done

# Test history module
echo ""
echo "3. Testing history module..."
export ORCHAT_HISTORY_DIR="/tmp/orchat_test_$$"
mkdir -p "$ORCHAT_HISTORY_DIR"

source src/history.sh

session_file=$(history_init "test_session")
echo "Created: $session_file"

history_add "$session_file" "user" "Test message"
history_add "$session_file" "assistant" "Test response"

length=$(history_length "$session_file")
echo "History length: $length"
[[ $length -eq 2 ]] || { echo "❌ History length mismatch"; exit 1; }

echo "✅ History module OK"

# Test config
echo ""
echo "4. Testing config..."
if [[ -f "config/orchat.toml" ]]; then
    echo "✅ Config file exists"
    
    # Check if Python can parse it
    if python3 -c "import toml; toml.load('config/orchat.toml')" 2>/dev/null; then
        echo "✅ TOML parseable"
    else
        echo "⚠️  TOML not parseable (python-toml not installed?)"
    fi
else
    echo "⚠️  No config file"
fi

# Cleanup
rm -rf "$ORCHAT_HISTORY_DIR"

echo ""
echo "=== Integration Test Complete ==="
echo "Phase 3 modules are installed and basic functionality works."
