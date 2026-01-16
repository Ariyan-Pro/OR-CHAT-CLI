#!/usr/bin/env bash
# Persistent conversation history (Python-assisted for safety)

HISTORY_DIR="${ORCHAT_HISTORY_DIR:-$HOME/.orchat/sessions}"
MAX_HISTORY_LENGTH="${MAX_HISTORY_LENGTH:-20}"

history_init() {
    local session_id="${1:-default}"
    mkdir -p "$HISTORY_DIR"
    local history_file="$HISTORY_DIR/$session_id.json"
    
    if [[ ! -f "$history_file" ]]; then
        echo '[]' > "$history_file"
    fi
    echo "$history_file"
}

history_add() {
    local history_file="$1"
    local role="$2"
    local content="$3"
    
    # Use Python for safe JSON manipulation
    python3 -c "
import json, sys
with open('$history_file', 'r') as f:
    history = json.load(f)
history.append({'role': '$role', 'content': '''$content'''})
# Trim if too long
if len(history) > $MAX_HISTORY_LENGTH:
    history = history[-$MAX_HISTORY_LENGTH:]
with open('$history_file', 'w') as f:
    json.dump(history, f, indent=2)
" 2>/dev/null || return 1
}

history_get_messages() {
    local history_file="$1"
    python3 -c "
import json, sys
try:
    with open('$history_file', 'r') as f:
        history = json.load(f)
    print(json.dumps(history))
except:
    print('[]')
" 2>/dev/null || echo '[]'
}

history_clear() {
    local history_file="$1"
    echo '[]' > "$history_file"
}

history_length() {
    local history_file="$1"
    python3 -c "
import json, sys
try:
    with open('$history_file', 'r') as f:
        history = json.load(f)
    print(len(history))
except:
    print(0)
" 2>/dev/null || echo "0"
}
# Python-assisted JSON dump (bulletproof)
history_dump_as_json_array() {
    local history_file="$1"
    
    if [[ ! -f "$history_file" ]]; then
        echo "[]"
        return 1
    fi
    
    # Use Python for safe JSON handling
    python3 -c "
import json, sys
try:
    with open('$history_file', 'r') as f:
        history = json.load(f)
    print(json.dumps(history))
except json.JSONDecodeError:
    print('[]')
except Exception as e:
    print(f'[]')
    sys.stderr.write(f'[ERROR] Failed to read history: {e}\\n')
" 2>/dev/null || echo '[]'
}

# Get messages for API (with optional trimming)
history_get_messages() {
    local history_file="$1"
    local max_messages="${2:-$MAX_HISTORY_LENGTH}"
    
    local all_messages
    all_messages=$(history_dump_as_json_array "$history_file")
    
    if [[ "$max_messages" -eq 0 ]]; then
        echo "$all_messages"
        return
    fi
    
    # Trim to max_messages using Python
    python3 -c "
import json, sys
try:
    messages = json.loads('''$all_messages''')
    if len(messages) > $max_messages:
        # Keep system message if present
        if messages and messages[0].get('role') == 'system':
            trimmed = [messages[0]] + messages[-(($max_messages)-1):]
        else:
            trimmed = messages[-$max_messages:]
        print(json.dumps(trimmed))
    else:
        print(json.dumps(messages))
except Exception as e:
    print('[]')
    sys.stderr.write(f'[ERROR] Failed to trim messages: {e}\\n')
" 2>/dev/null || echo "$all_messages"
}

# Clear history file
history_clear() {
    local history_file="$1"
    echo '[]' > "$history_file"
}

# Get history length
history_length() {
    local history_file="$1"
    
    python3 -c "
import json, sys
try:
    with open('$history_file', 'r') as f:
        history = json.load(f)
    print(len(history))
except:
    print(0)
" 2>/dev/null || echo "0"
}
