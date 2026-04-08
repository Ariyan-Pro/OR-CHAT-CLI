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
    
    # Use stdin and arguments to avoid command injection
    echo "$content" | python3 - "$history_file" "$role" "$MAX_HISTORY_LENGTH" << 'PYTHON_EOF'
import json, sys
history_file = sys.argv[1]
role = sys.argv[2]
max_length = int(sys.argv[3])
content = sys.stdin.read()

with open(history_file, 'r') as f:
    history = json.load(f)
history.append({'role': role, 'content': content})
# Trim if too long
if len(history) > max_length:
    history = history[-max_length:]
with open(history_file, 'w') as f:
    json.dump(history, f, indent=2)
PYTHON_EOF
}

history_get_messages() {
    local history_file="$1"
    python3 - "$history_file" << 'PYTHON_EOF'
import json, sys
try:
    history_file = sys.argv[1]
    with open(history_file, 'r') as f:
        history = json.load(f)
    print(json.dumps(history))
except:
    print('[]')
PYTHON_EOF
}

history_clear() {
    local history_file="$1"
    echo '[]' > "$history_file"
}

history_length() {
    local history_file="$1"
    python3 - "$history_file" << 'PYTHON_EOF'
import json, sys
try:
    history_file = sys.argv[1]
    with open(history_file, 'r') as f:
        history = json.load(f)
    print(len(history))
except:
    print(0)
PYTHON_EOF
}

# Python-assisted JSON dump (bulletproof)
history_dump_as_json_array() {
    local history_file="$1"
    
    if [[ ! -f "$history_file" ]]; then
        echo "[]"
        return 1
    fi
    
    # Use Python for safe JSON handling
    python3 - "$history_file" << 'PYTHON_EOF'
import json, sys
try:
    history_file = sys.argv[1]
    with open(history_file, 'r') as f:
        history = json.load(f)
    print(json.dumps(history))
except json.JSONDecodeError:
    print('[]')
except Exception as e:
    print('[]')
    sys.stderr.write(f'[ERROR] Failed to read history: {e}\n')
PYTHON_EOF
}

# Get messages for API (with optional trimming)
history_get_messages_trimmed() {
    local history_file="$1"
    local max_messages="${2:-$MAX_HISTORY_LENGTH}"
    
    local all_messages
    all_messages=$(history_dump_as_json_array "$history_file")
    
    if [[ "$max_messages" -eq 0 ]]; then
        echo "$all_messages"
        return
    fi
    
    # Trim to max_messages using Python with stdin to avoid command injection
    echo "$all_messages" | python3 - "$max_messages" << 'PYTHON_EOF'
import json, sys
try:
    messages = json.loads(sys.stdin.read())
    max_messages = int(sys.argv[1])
    if len(messages) > max_messages:
        # Keep system message if present
        if messages and messages[0].get('role') == 'system':
            trimmed = [messages[0]] + messages[-(max_messages-1):]
        else:
            trimmed = messages[-max_messages:]
        print(json.dumps(trimmed))
    else:
        print(json.dumps(messages))
except Exception as e:
    print('[]')
    sys.stderr.write(f'[ERROR] Failed to trim messages: {e}\n')
PYTHON_EOF
}
