#!/usr/bin/env bash
set -eo pipefail

# Session management for Phase 3

SESSION_DIR="${ORCHAT_SESSION_DIR:-$HOME/.orchat/sessions}"
mkdir -p "$SESSION_DIR"

session_create() {
    local session_name="${1:-}"
    local system_prompt="${2:-}"
    
    if [[ -z "$session_name" ]]; then
        session_name="session_$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Sanitize session name to prevent path traversal
    session_name=$(echo "$session_name" | tr -cd '[:alnum:]_-')
    
    if [[ -z "$session_name" ]]; then
        echo "[ERROR] Invalid session name" >&2
        return 1
    fi
    
    local session_file="$SESSION_DIR/$session_name.json"
    
    # Use atomic file creation with mktemp to prevent TOCTOU race conditions
    local temp_file
    temp_file=$(mktemp "${SESSION_DIR}/.session.XXXXXX.json") || {
        echo "[ERROR] Failed to create session file" >&2
        return 1
    }
    
    # Create session content in temp file first
    cat > "$temp_file" << SESSION_EOF
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
    
    # Atomically move temp file to final location
    if ! mv "$temp_file" "$session_file" 2>/dev/null; then
        rm -f "$temp_file"
        echo "[ERROR] Failed to save session" >&2
        return 1
    fi
    
    echo "$session_file"
}

session_load() {
    local session_file="$1"
    
    # Validate session file path - must be a filename only (no path components)
    if [[ "$session_file" =~ / ]]; then
        echo "[ERROR] Invalid session file path" >&2
        return 1
    fi
    
    # Construct full path within SESSION_DIR
    session_file="$SESSION_DIR/$session_file.json"
    
    # Verify file exists and is within SESSION_DIR
    local real_session_dir
    real_session_dir=$(cd "$SESSION_DIR" 2>/dev/null && pwd -P) || {
        echo "[ERROR] Session directory not accessible" >&2
        return 1
    }
    
    if [[ ! -f "$session_file" ]]; then
        echo "[ERROR] Session file not found" >&2
        return 1
    fi
    
    # Get realpath to verify it's in the correct directory
    local real_file_path
    real_file_path=$(readlink -f "$session_file" 2>/dev/null) || {
        echo "[ERROR] Cannot resolve session file path" >&2
        return 1
    }
    
    if [[ ! "$real_file_path" =~ ^"$real_session_dir"/ ]]; then
        echo "[ERROR] Security violation: session file outside allowed directory" >&2
        return 1
    fi
    
    # Extract messages from session using stdin to avoid command injection
    python3 - "$session_file" << 'PYTHON_EOF'
import json, sys
try:
    session_file = sys.argv[1]
    with open(session_file, 'r') as f:
        session = json.load(f)
    messages = json.dumps(session.get('messages', []))
    print(messages)
except Exception as e:
    print('[]')
    sys.stderr.write('[ERROR] Failed to load session\n')
PYTHON_EOF
}

session_save() {
    local session_file="$1"
    local messages_json="$2"
    local timestamp
    timestamp=$(date -Iseconds)
    
    # Validate session file path to prevent path traversal
    if [[ ! "$session_file" =~ ^[^/]+$ ]] && [[ ! "$session_file" =~ \.json$ ]]; then
        echo "[ERROR] Invalid session file path" >&2
        return 1
    fi
    
    # Use atomic file operations with mktemp to prevent TOCTOU race conditions
    local temp_file
    temp_file=$(mktemp "${SESSION_DIR}/.session_save.XXXXXX.json") || {
        echo "[ERROR] Failed to create temporary file" >&2
        return 1
    }
    
    # Ensure cleanup on failure
    trap 'rm -f "$temp_file"' RETURN
    
    # Copy existing session to temp file first
    if [[ -f "$session_file" ]]; then
        cp "$session_file" "$temp_file" || {
            echo "[ERROR] Failed to read session file" >&2
            return 1
        }
    fi
    
    # Use stdin and arguments to avoid command injection
    echo "$messages_json" | python3 - "$temp_file" "$timestamp" "$session_file" << 'PYTHON_EOF'
import json, sys
temp_file = sys.argv[1]
timestamp = sys.argv[2]
final_file = sys.argv[3]
messages = sys.stdin.read()

try:
    # Load existing session from temp file
    with open(temp_file, 'r') as f:
        session = json.load(f)
    
    # Update messages
    session['messages'] = json.loads(messages) if messages.strip() else []
    session['metadata']['updated'] = timestamp
    
    # Save to temp file first
    with open(temp_file, 'w') as f:
        json.dump(session, f, indent=2)
    
    # Atomically move to final location
    import os
    os.rename(temp_file, final_file)
    print('Session saved:', final_file)
except Exception as e:
    print(f'Failed to save session: {e}', file=sys.stderr)
    sys.exit(1)
PYTHON_EOF
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
        session_info=$(python3 - "$session_file" << 'PYTHON_EOF'
import json, os, sys
try:
    session_file = sys.argv[1]
    with open(session_file, 'r') as f:
        session = json.load(f)
    meta = session.get('metadata', {})
    name = meta.get('name', os.path.basename(session_file))
    created = meta.get('created', 'unknown')
    model = meta.get('model', 'unknown')
    msg_count = len(session.get('messages', []))
    print(f'{name:30s} | {model:25s} | {msg_count:3d} msgs | {created[:10]}')
except:
    print(f'{session_file} (corrupted)')
PYTHON_EOF
)
        
        echo "$session_info"
        ((count++))
    done
    
    echo "Total: $count sessions"
}

session_delete() {
    local session_name="$1"
    
    # Sanitize session name to prevent path traversal
    session_name=$(echo "$session_name" | tr -cd '[:alnum:]_-')
    
    if [[ -z "$session_name" ]]; then
        echo "[ERROR] Invalid session name" >&2
        return 1
    fi
    
    local session_file="$SESSION_DIR/$session_name.json"
    
    # Verify file exists and is within SESSION_DIR (prevent path traversal)
    local real_session_dir
    real_session_dir=$(cd "$SESSION_DIR" 2>/dev/null && pwd -P) || {
        echo "[ERROR] Session directory not accessible" >&2
        return 1
    }
    
    # Check if file exists before attempting deletion
    if [[ ! -f "$session_file" ]]; then
        echo "[ERROR] Session not found: $session_name" >&2
        return 1
    fi
    
    # Get realpath of session file to verify it's in the correct directory
    local real_file_path
    real_file_path=$(readlink -f "$session_file" 2>/dev/null) || {
        echo "[ERROR] Cannot resolve session file path" >&2
        return 1
    }
    
    if [[ ! "$real_file_path" =~ ^"$real_session_dir"/ ]]; then
        echo "[ERROR] Security violation: session file outside allowed directory" >&2
        return 1
    fi
    
    rm -f "$session_file"
    echo "Deleted session: $session_name"
}

session_cleanup() {
    local max_age_days="${1:-7}"
    
    echo "Cleaning up sessions older than $max_age_days days..."
    
    python3 - "$SESSION_DIR" "$max_age_days" << 'PYTHON_EOF'
import os, json, datetime, sys
session_dir = sys.argv[1]
max_days = int(sys.argv[2])

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
PYTHON_EOF
}

# Handle session subcommands (create, list, stats, cleanup)
session_handle() {
    local subcommand="${1:-}"
    
    case "$subcommand" in
        create)
            local name="${2:-}"
            local system="${3:-}"
            session_create "$name" "$system"
            ;;
        list)
            session_list
            ;;
        stats)
            echo "Session statistics not yet implemented"
            ;;
        cleanup)
            local max_age="${2:-7}"
            session_cleanup "$max_age"
            ;;
        delete)
            local name="${2:-}"
            if [[ -z "$name" ]]; then
                echo "[ERROR] Usage: session delete requires a name argument" >&2
                exit 1
            fi
            session_delete "$name"
            ;;
        *)
            echo "Usage: orchat session <create|list|stats|cleanup|delete>" >&2
            echo "  create [name] [system_prompt] - Create a new session" >&2
            echo "  list                          - List all sessions" >&2
            echo "  stats                         - Show session statistics" >&2
            echo "  cleanup [days]                - Clean up old sessions" >&2
            echo "  delete <name>                 - Delete a specific session" >&2
            exit 1
            ;;
    esac
}
