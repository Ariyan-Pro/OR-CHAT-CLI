#!/usr/bin/env bash
# Structured message composition with validation

validate_message() {
    local role="$1"
    local content="$2"
    
    # Basic validation
    [[ -z "$role" ]] && return 1
    [[ -z "$content" ]] && return 1
    [[ "$role" =~ ^(system|user|assistant)$ ]] || return 1
    
    # Content length check (crude token estimation)
    local length="${#content}"
    if [[ $length -gt 10000 ]]; then
        echo "[WARN] Message very long ($length chars)" >&2
    fi
    
    return 0
}

build_message_stack() {
    local system_prompt="$1"
    local user_message="$2"
    local history_json="$3"
    
    # Start with empty array
    local messages='[]'
    
    # Use Python for robust JSON construction
    python3 -c "
import json, sys

system = '''$system_prompt''' if '$system_prompt' else None
user = '''$user_message'''
history = '''$history_json'''

try:
    messages = json.loads(history) if history.strip() else []
except:
    messages = []

# Add system prompt if provided (only once at beginning)
if system and (not messages or messages[0].get('role') != 'system'):
    messages.insert(0, {'role': 'system', 'content': system})

# Add current user message
messages.append({'role': 'user', 'content': user})

# Trim if too many messages (keep system + last N)
max_messages = 10
if len(messages) > max_messages:
    if messages[0].get('role') == 'system':
        system_msg = messages[0]
        messages = [system_msg] + messages[-(max_messages-1):]
    else:
        messages = messages[-max_messages:]

print(json.dumps(messages))
" 2>/dev/null || echo '[]'
}

trim_context() {
    local messages_json="$1"
    local max_tokens="${2:-4000}"
    
    python3 -c "
import json, sys
messages = json.loads('''$messages_json''')
max_len = $max_tokens

# Simple character-based trimming (crude)
total_chars = sum(len(m['content']) for m in messages)
if total_chars <= max_len:
    print(json.dumps(messages))
    sys.exit(0)

# Remove oldest non-system messages
while total_chars > max_len and len(messages) > 1:
    if messages[0].get('role') == 'system' and len(messages) > 2:
        removed = messages.pop(1)  # Keep system, remove first user/assistant
    else:
        removed = messages.pop(0)
    total_chars -= len(removed['content'])

print(json.dumps(messages))
" 2>/dev/null || echo "$messages_json"
}
# Alias for compatibility with test
validate_message_stack() {
    validate_message_stack "$@"
}
