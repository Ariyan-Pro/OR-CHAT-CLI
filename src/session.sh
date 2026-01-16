#!/usr/bin/env bash
set -euo pipefail

# Session management for Phase 3

SESSION_DIR="${ORCHAT_SESSION_DIR:-$HOME/.orchat/sessions}"
mkdir -p "$SESSION_DIR"

session_create() {
    local session_name="${1:-}"
    local system_prompt="${2:-}"
    
    if [[ -z "$session_name" ]]; then
        session_name="session_$(date +%Y%m%d_%H%M%S)"
    fi
    
    local session_file="$SESSION_DIR/$session_name.json"
    
    # Create session file
    cat > "$session_file" << SESSION_EOF
{
  "metadata": {
    "name": "$session_name",
    "created": "$(date -Iseconds)",
    "model": "${RESOLVED_MODEL:-openai/gpt-3.5-turbo}",
    "temperature": ${RESOLVED_TEMPERATURE:-0.7}
  },
  "system_prompt": "$system_prompt",
  "messages": []
}
SESSION_EOF
    
    echo "$session_file"
}

session_load() {
    local session_file="$1"
    
    if [[ ! -f "$session_file" ]]; then
        echo "[ERROR] Session file not found: $session_file" >&2
        return 1
    fi
    
    # Extract messages from session
    python3 -c "
import json, sys
try:
    with open('$session_file', 'r') as f:
        session = json.load(f)
    messages = json.dumps(session.get('messages', []))
    print(messages)
except Exception as e:
    print(f'[]')
    sys.stderr.write(f'[ERROR] Failed to load session: {e}\\n')
" 2>/dev/null || echo '[]'
}

session_save() {
    local session_file="$1"
    local messages_json="$2"
    
    python3 -c "
import json, sys
session_file = '$session_file'
messages = '''$messages_json'''

try:
    # Load existing session
    with open(session_file, 'r') as f:
        session = json.load(f)
    
    # Update messages
    session['messages'] = json.loads(messages) if messages.strip() else []
    session['metadata']['updated'] = '$(date -Iseconds)'
    
    # Save
    with open(session_file, 'w') as f:
        json.dump(session, f, indent=2)
    
    print('Session saved:', session_file)
except Exception as e:
    print(f'Failed to save session: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null || return 1
}

session_list() {
    echo "=== Saved Sessions ==="
    
    if [[ ! -d "$SESSION_DIR" ]] || [[ -z "$(ls -A "$SESSION_DIR" 2>/dev/null)" ]]; then
        echo "No saved sessions found"
        return 0
    fi
    
    local count=0
    for session_file in "$SESSION_DIR"/*.json; do
        [[ -f "$session_file" ]] || continue
        
        local session_info
        session_info=$(python3 -c "
import json, os, sys
try:
    with open('$session_file', 'r') as f:
        session = json.load(f)
    meta = session.get('metadata', {})
    name = meta.get('name', os.path.basename('$session_file'))
    created = meta.get('created', 'unknown')
    model = meta.get('model', 'unknown')
    msg_count = len(session.get('messages', []))
    print(f'{name:30s} | {model:25s} | {msg_count:3d} msgs | {created[:10]}')
except:
    print(f'$session_file (corrupted)')
" 2>/dev/null)
        
        echo "$session_info"
        ((count++))
    done
    
    echo "Total: $count sessions"
}

session_delete() {
    local session_name="$1"
    local session_file="$SESSION_DIR/$session_name.json"
    
    if [[ ! -f "$session_file" ]]; then
        echo "[ERROR] Session not found: $session_name" >&2
        return 1
    fi
    
    rm -f "$session_file"
    echo "Deleted session: $session_name"
}

session_cleanup() {
    local max_age_days="${1:-7}"
    
    echo "Cleaning up sessions older than $max_age_days days..."
    
    python3 -c "
import os, json, datetime, sys
session_dir = '$SESSION_DIR'
max_days = $max_age_days

if not os.path.exists(session_dir):
    print('No session directory')
    sys.exit(0)

deleted = 0
for filename in os.listdir(session_dir):
    if not filename.endswith('.json'):
        continue
    
    filepath = os.path.join(session_dir, filename)
    
    try:
        # Try to get creation time from metadata
        with open(filepath, 'r') as f:
            session = json.load(f)
        created_str = session.get('metadata', {}).get('created', '')
        
        if created_str:
            created = datetime.datetime.fromisoformat(created_str.replace('Z', '+00:00'))
        else:
            # Use file modification time
            created = datetime.datetime.fromtimestamp(os.path.getmtime(filepath))
        
        age = (datetime.datetime.now() - created).days
        
        if age > max_days:
            os.remove(filepath)
            print(f'Deleted: {filename} ({age} days old)')
            deleted += 1
            
    except Exception as e:
        print(f'Error processing {filename}: {e}')

print(f'Cleanup complete: {deleted} sessions deleted')
" 2>/dev/null
}
