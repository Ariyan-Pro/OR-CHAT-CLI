#!/usr/bin/env bash
set -euo pipefail

start_interactive() {
    local hist_file="${1:-${RESOLVED_HISTORY_FILE:-$HOME/.orchat_history}}"
    local system_file="${2:-${RESOLVED_SYSTEM_FILE:-}}"
    
    # Load history module
    if ! type history_init &>/dev/null; then
        echo "[ERROR] History module not loaded" >&2
        return 1
    fi
    
    # Initialize session
    local session_id="session_$(date +%Y%m%d_%H%M%S)"
    local session_file
    session_file=$(history_init "$session_id")
    
    echo "=== ORCHAT INTERACTIVE MODE (Phase 3) ==="
    echo "Session: $session_id"
    echo "Model: ${RESOLVED_MODEL:-openai/gpt-3.5-turbo}"
    echo "System: ${system_file:-<default>}"
    echo "Type '/exit' to quit, '/clear' to clear history, '/history' to view"
    echo "=========================================="
    
    # Load system prompt if provided
    local system_prompt=""
    if [[ -n "$system_file" ]] && [[ -f "$system_file" ]]; then
        system_prompt=$(<"$system_file")
        echo "Loaded system prompt from: $system_file"
    fi
    
    while true; do
        # Read input with readline support
        if command -v rlwrap >/dev/null 2>&1; then
            read -e -p "> " -r input
        else
            read -p "> " -r input
        fi
        
        # Handle commands
        case "$input" in
            "/exit")
                echo "Exiting interactive mode. Session saved to: $session_file"
                break
                ;;
            "/clear")
                history_clear "$session_file"
                echo "History cleared"
                continue
                ;;
            "/history")
                echo "=== Conversation History ==="
                python3 -c "
import json, sys
try:
    with open('$session_file', 'r') as f:
        history = json.load(f)
    for i, msg in enumerate(history):
        role = msg.get('role', 'unknown')
        content = msg.get('content', '')[:100]
        print(f'{i:2d}. {role:10s}: {content}')
except Exception as e:
    print(f'Error reading history: {e}')
" 2>/dev/null || echo "Could not read history"
                echo "==========================="
                continue
                ;;
            "/help")
                echo "Commands:"
                echo "  /exit     - Exit interactive mode"
                echo "  /clear    - Clear conversation history"
                echo "  /history  - Show conversation history"
                echo "  /help     - Show this help"
                echo "  /save     - Save session to file"
                echo "  /load     - Load session from file"
                continue
                ;;
            "")
                continue
                ;;
        esac
        
        # Add user message to history
        history_add "$session_file" "user" "$input"
        
        # Build message stack
        local history_json
        history_json=$(history_get_messages "$session_file")
        
        # Get system prompt for this session
        if [[ -z "$system_prompt" ]] && [[ -f "data/messages/system/default.md" ]]; then
            system_prompt=$(<"data/messages/system/default.md")
        fi
        
        # Build message stack using context module
        local messages_json
        if type build_message_stack &>/dev/null; then
            messages_json=$(build_message_stack "$system_prompt" "$input" "$history_json")
        else
            # Fallback to simple message
            messages_json='[{"role": "user", "content": "'"$input"'"}]'
        fi
        
        # Get response
        echo -n "Assistant: "
        
        if type payload_build &>/dev/null && type run_orchat_stream &>/dev/null; then
            # Use payload builder for streaming
            local payload
            payload=$(payload_build "$messages_json" "${RESOLVED_MODEL:-openai/gpt-3.5-turbo}" "${RESOLVED_TEMPERATURE:-0.7}" "true")
            
            if [[ -n "$payload" ]]; then
                # Create temp file for response
                local response_file
                response_file=$(mktemp)
                
                # Make API call and capture response
                curl --no-buffer -sS -X POST "$ORCHAT_API_URL" \
                    -H "Authorization: Bearer $OPENROUTER_API_KEY" \
                    -H "Content-Type: application/json" \
                    -d "$payload" 2>/dev/null | \
                    handle_stream_chunks | tee "$response_file"
                
                # Add assistant response to history
                local response_content
                response_content=$(<"$response_file")
                if [[ -n "$response_content" ]]; then
                    history_add "$session_file" "assistant" "$response_content"
                fi
                
                rm -f "$response_file"
            fi
        else
            # Fallback to non-streaming
            local response
            response=$(run_orchat "$input")
            echo "$response"
            
            # Add to history
            history_add "$session_file" "assistant" "$response"
        fi
        
        echo ""
    done
}
