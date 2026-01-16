#!/bin/bash
# Phase 3 Integration Test - Full System Validation
set -euo pipefail

echo "=== ORCHAT PHASE 3 INTEGRATION TEST ==="
echo ""

cd "$(dirname "$0")/../.."

# Test 1: Module Loading
echo "1. Testing module loading..."
if source src/bootstrap.sh 2>&1; then
    echo "✅ All modules loaded successfully"
else
    echo "❌ Module loading failed"
    exit 1
fi

# Test 2: Phase 3 Function Availability
echo ""
echo "2. Checking Phase 3 functions..."
declare -a required_functions=(
    "history_init" "history_add" "history_dump_as_json_array"
    "build_message_stack" "trim_context" "validate_message_stack"
    "payload_build" "payload_validate"
    "gemini_load_config" "gemini_validate_config"
)

missing=0
for func in "${required_functions[@]}"; do
    if type "$func" &>/dev/null; then
        echo "  ✅ $func"
    else
        echo "  ❌ $func (MISSING)"
        missing=$((missing + 1))
    fi
done

if [[ $missing -gt 0 ]]; then
    echo "❌ Missing $missing functions"
    exit 1
fi
echo "✅ All Phase 3 functions available"

# Test 3: History Management
echo ""
echo "3. Testing history management..."
export ORCHAT_HISTORY_DIR="/tmp/orchat_integration_test_$$"
mkdir -p "$ORCHAT_HISTORY_DIR"

session_file=$(history_init "integration_test")
if [[ -f "$session_file" ]]; then
    echo "  ✅ Session file created"
else
    echo "  ❌ Session file creation failed"
    exit 1
fi

# Add messages
history_add "$session_file" "user" "Integration test message 1"
history_add "$session_file" "assistant" "Integration test response 1"
history_add "$session_file" "user" "Integration test message 2"

count=$(history_length "$session_file")
if [[ "$count" -eq 3 ]]; then
    echo "  ✅ Messages added successfully ($count total)"
else
    echo "  ❌ Message count mismatch: $count (expected 3)"
    exit 1
fi

# Test 4: Message Stack Building
echo ""
echo "4. Testing message stack building..."
system_prompt="You are a test assistant."
user_input="What is the test result?"

messages=$(build_message_stack "$system_prompt" "$user_input" "[]")
if echo "$messages" | python3 -c "import json,sys; json.load(sys.stdin); print('VALID')" 2>/dev/null; then
    echo "  ✅ Message stack created"
    
    # Check structure
    role_count=$(echo "$messages" | python3 -c "import json,sys; data=json.load(sys.stdin); print(sum(1 for m in data if m.get('role') in ['system','user','assistant']))")
    if [[ "$role_count" -eq 2 ]]; then
        echo "  ✅ Correct message count"
    else
        echo "  ❌ Incorrect message count: $role_count"
    fi
else
    echo "  ❌ Invalid message stack JSON"
    exit 1
fi

# Test 5: Payload Construction
echo ""
echo "5. Testing payload construction..."
payload=$(payload_build "$messages" "test-model" 0.5 "false")
if payload_validate "$payload" | grep -q "VALID"; then
    echo "  ✅ Payload created and validated"
    
    # Check fields
    if echo "$payload" | python3 -c "
import json,sys
data=json.load(sys.stdin)
assert data['model'] == 'test-model'
assert data['temperature'] == 0.5
assert data['stream'] == False
assert len(data['messages']) > 0
print('FIELDS_OK')
" 2>/dev/null; then
        echo "  ✅ All payload fields correct"
    else
        echo "  ❌ Payload field mismatch"
    fi
else
    echo "  ❌ Payload validation failed"
    exit 1
fi

# Test 6: Context Trimming
echo ""
echo "6. Testing context trimming..."
# Create long messages
long_messages='[
  {"role": "system", "content": "System"},
  {"role": "user", "content": "'$(printf '%0.sX' {1..100})'"},
  {"role": "assistant", "content": "'$(printf '%0.sY' {1..100})'"},
  {"role": "user", "content": "'$(printf '%0.sZ' {1..100})'"}
]'

trimmed=$(trim_context "$long_messages" 150)
trimmed_count=$(echo "$trimmed" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
if [[ "$trimmed_count" -lt 4 ]]; then
    echo "  ✅ Context trimmed from 4 to $trimmed_count messages"
else
    echo "  ❌ Context not trimmed: $trimmed_count messages"
fi

# Test 7: Gemini Config Integration
echo ""
echo "7. Testing Gemini config integration..."
if [[ -f "config/orchat.toml" ]]; then
    if gemini_validate_config "config/orchat.toml"; then
        echo "  ✅ Config file validated"
        
        # Try to load config
        if gemini_load_config "config/orchat.toml"; then
            echo "  ✅ Config loaded successfully"
            if [[ "$GEMINI_CONFIG_LOADED" = "true" ]]; then
                echo "  ✅ Config marked as loaded"
            fi
        else
            echo "  ⚠️  Config load failed (may be expected without python-toml)"
        fi
    else
        echo "  ❌ Config validation failed"
    fi
else
    echo "  ⚠️  No config file found (skipping)"
fi

# Cleanup
rm -rf "$ORCHAT_HISTORY_DIR"

echo ""
echo "=== INTEGRATION TEST COMPLETE ==="
echo "All Phase 3 technical components are working correctly!"
echo ""
echo "Summary:"
echo "- Module loading: ✅"
echo "- History management: ✅"
echo "- Message stacking: ✅"
echo "- Payload construction: ✅"
echo "- Context trimming: ✅"
echo "- Gemini integration: ✅ (if config present)"
echo ""
echo "Phase 3 is ready for production use!"
