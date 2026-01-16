#!/bin/bash
# ORCHAT Session Manager - Advanced Features Module 1
# Workstream 3: Session Management

# Session storage directory
SESSION_DIR="${ORCHAT_SESSION_DIR:-$HOME/.orchat/sessions}"
SESSION_RETENTION_DAYS=${ORCHAT_SESSION_RETENTION:-30}
MAX_SESSIONS=${ORCHAT_MAX_SESSIONS:-100}

# Initialize session system
init_sessions() {
    mkdir -p "$SESSION_DIR"
    echo "Session system initialized: $SESSION_DIR"
}

# Create a new session
create_session() {
    local session_id=$(uuidgen | tr '[:upper:]' '[:lower:]')
    local session_file="$SESSION_DIR/$session_id.json"
    
    cat > "$session_file" << SESSION_EOF
{
    "session_id": "$session_id",
    "created_at": "$(date -Iseconds)",
    "updated_at": "$(date -Iseconds)",
    "model": "${1:-openai/gpt-3.5-turbo}",
    "temperature": ${2:-0.7},
    "messages": [],
    "metadata": {
        "total_tokens": 0,
        "message_count": 0,
        "last_activity": "$(date -Iseconds)"
    }
}
SESSION_EOF
    
    echo "$session_id"
}

# Load a session
load_session() {
    local session_id=$1
    local session_file="$SESSION_DIR/$session_id.json"
    
    if [[ -f "$session_file" ]]; then
        cat "$session_file"
    else
        echo "{}"
        return 1
    fi
}

# Save a session
save_session() {
    local session_id=$1
    local session_data=$2
    local session_file="$SESSION_DIR/$session_id.json"
    
    echo "$session_data" > "$session_file"
}

# Add message to session
add_to_session() {
    local session_id=$1
    local role=$2
    local content=$3
    local session_file="$SESSION_DIR/$session_id.json"
    
    if [[ -f "$session_file" ]]; then
        # Use Python for complex JSON manipulation
        python3 -c "
import json, sys, datetime
with open('$session_file', 'r') as f:
    session = json.load(f)

message = {
    'role': '$role',
    'content': "$content",
    'timestamp': datetime.datetime.now().isoformat()
}

session['messages'].append(message)
session['updated_at'] = datetime.datetime.now().isoformat()
session['metadata']['message_count'] = len(session['messages'])
session['metadata']['last_activity'] = datetime.datetime.now().isoformat()

with open('$session_file', 'w') as f:
    json.dump(session, f, indent=2)
"
        echo "Message added to session: $session_id"
    else
        echo "Session not found: $session_id"
        return 1
    fi
}

# List all sessions
list_sessions() {
    echo "=== ACTIVE SESSIONS ==="
    echo ""
    
    if [[ -d "$SESSION_DIR" ]]; then
        local count=0
        for session_file in "$SESSION_DIR"/*.json; do
            if [[ -f "$session_file" ]]; then
                local session_id=$(basename "$session_file" .json)
                local created=$(grep -o '"created_at":"[^"]*"' "$session_file" | head -1 | cut -d'"' -f4)
                local message_count=$(grep -o '"message_count":[0-9]*' "$session_file" | cut -d':' -f2)
                local last_activity=$(grep -o '"last_activity":"[^"]*"' "$session_file" | cut -d'"' -f4)
                
                echo "Session: $session_id"
                echo "  Created: $created"
                echo "  Messages: ${message_count:-0}"
                echo "  Last Activity: $last_activity"
                echo ""
                count=$((count + 1))
            fi
        done
        
        if [[ $count -eq 0 ]]; then
            echo "No active sessions found"
        else
            echo "Total sessions: $count"
        fi
    else
        echo "Session directory not found: $SESSION_DIR"
    fi
}

# Cleanup old sessions
cleanup_sessions() {
    if [[ -d "$SESSION_DIR" ]]; then
        find "$SESSION_DIR" -name "*.json" -type f -mtime "+$SESSION_RETENTION_DAYS" -delete
        echo "Cleaned up sessions older than $SESSION_RETENTION_DAYS days"
    fi
}

# Export session to file
export_session() {
    local session_id=$1
    local export_file="${2:-$session_id.export.json}"
    local session_file="$SESSION_DIR/$session_id.json"
    
    if [[ -f "$session_file" ]]; then
        cp "$session_file" "$export_file"
        echo "Session exported to: $export_file"
    else
        echo "Session not found: $session_id"
        return 1
    fi
}

# Import session from file
import_session() {
    local import_file=$1
    local session_id=$(basename "$import_file" .export.json)
    local session_file="$SESSION_DIR/$session_id.json"
    
    if [[ -f "$import_file" ]]; then
        cp "$import_file" "$session_file"
        echo "Session imported: $session_id"
    else
        echo "Import file not found: $import_file"
        return 1
    fi
}

# Session statistics
session_stats() {
    echo "=== SESSION STATISTICS ==="
    echo ""
    
    if [[ -d "$SESSION_DIR" ]]; then
        local total_sessions=0
        local total_messages=0
        local oldest_session=""
        local newest_session=""
        
        for session_file in "$SESSION_DIR"/*.json; do
            if [[ -f "$session_file" ]]; then
                total_sessions=$((total_sessions + 1))
                local message_count=$(grep -o '"message_count":[0-9]*' "$session_file" | cut -d':' -f2)
                total_messages=$((total_messages + ${message_count:-0}))
                
                local created=$(grep -o '"created_at":"[^"]*"' "$session_file" | head -1 | cut -d'"' -f4)
                if [[ -z "$oldest_session" ]] || [[ "$created" < "$oldest_session" ]]; then
                    oldest_session="$created"
                fi
                if [[ -z "$newest_session" ]] || [[ "$created" > "$newest_session" ]]; then
                    newest_session="$created"
                fi
            fi
        done
        
        echo "Total Sessions: $total_sessions"
        echo "Total Messages: $total_messages"
        echo "Oldest Session: $oldest_session"
        echo "Newest Session: $newest_session"
        echo "Average Messages/Session: $(if [[ $total_sessions -gt 0 ]]; then echo "scale=2; $total_messages / $total_sessions" | bc; else echo "0"; fi)"
    else
        echo "No session data available"
    fi
}

# Initialize on source
init_sessions
