#!/usr/bin/env bash
set -euo pipefail

validate_input() {
    local input="$1"
    local min_len="${2:-1}"
    local max_len="${3:-4000}"
    local len="${#input}"
    
    if [[ $len -lt $min_len ]]; then
        echo "[ERROR] Input too short (< $min_len chars)" >&2
        return 6  # E_INVALID_INPUT
    fi
    if [[ $len -gt $max_len ]]; then
        echo "[ERROR] Input too long (> $max_len chars)" >&2
        return 6  # E_INVALID_INPUT
    fi
    return 0
}

# SAFE JSON PARSING - NEVER EXITS
clean_json_output() {
    local response
    response="$(cat 2>/dev/null || echo '')"
    
    if [[ -z "$response" ]]; then
        echo "[ERROR] Empty response from API" >&2
        return 1
    fi
    
    # Try to parse with jq
    local parsed
    if parsed=$(echo "$response" | jq -r '.choices[0].message.content // .choices[0].text // .choices[0].delta.content // .error.message // .error // empty' 2>/dev/null); then
        if [[ -n "$parsed" ]]; then
            echo "$parsed"
            return 0
        fi
    fi
    
    # If parsing failed, show raw for debugging
    echo "[DEBUG] Raw response:" >&2
    echo "$response" | head -c 200 >&2
    echo "" >&2
    echo "[ERROR] Could not parse API response" >&2
    return 1
}
