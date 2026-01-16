#!/usr/bin/env bash
set -euo pipefail

validate_api_key() {
    # Check if API key is set
    if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
        # Try to load from file
        if [[ -f "$HOME/.orchat_api_key" ]]; then
            OPENROUTER_API_KEY=$(<"$HOME/.orchat_api_key")
            export OPENROUTER_API_KEY
        fi
    fi
    
    # If still empty, check if we're in interactive mode
    if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
        # In non-interactive mode, we need a key
        if [[ "${1:-}" != "interactive" ]]; then
            echo "[ERROR] OpenRouter API key not set!" >&2
            echo "" >&2
            echo "Set it with:" >&2
            echo "  export OPENROUTER_API_KEY='your-key-here'" >&2
            echo "  orchat --set-key 'your-key-here'" >&2
            echo "  orchat --setup (for guided setup)" >&2
            echo "" >&2
            echo "Get a key from: https://openrouter.ai/keys" >&2
            exit 1  # E_KEY_MISSING
        fi
    fi
    
    # Validate key format (basic check)
    if [[ -n "${OPENROUTER_API_KEY:-}" ]] && [[ ${#OPENROUTER_API_KEY} -lt 20 ]]; then
        echo "[WARN] API key seems too short (${#OPENROUTER_API_KEY} chars)" >&2
    fi
}

# Check for required commands
check_dependencies() {
    local missing=()
    
    for cmd in curl jq; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "[ERROR] Missing dependencies: ${missing[*]}" >&2
        echo "Install with:" >&2
        echo "  Ubuntu/Debian: sudo apt install curl jq" >&2
        echo "  macOS: brew install curl jq" >&2
        exit 7  # E_INTERNAL
    fi
}
