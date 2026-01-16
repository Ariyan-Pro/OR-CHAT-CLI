#!/usr/bin/env bash
set -euo pipefail

CURL_OPTS=(-sS --fail --show-error --max-time 30)

# small retry mechanism
_http_post() {
    local data="$1"
    local attempt=0
    local max=2
    local resp
    while true; do
        resp="$(curl "${CURL_OPTS[@]}" -X POST "$ORCHAT_API_URL" \
            -H "Authorization: Bearer $OPENROUTER_API_KEY" \
            -H "Content-Type: application/json" \
            -d "$data" 2>&1)" || rc=$? && rc=${rc:-0}
        if [[ ${rc:-0} -eq 0 ]]; then
            printf '%s' "$resp"
            return 0
        fi
        attempt=$((attempt+1))
        if [[ $attempt -gt $max ]]; then
            echo "[ERROR] Network/API failure: $resp" >&2
            return 3  # E_NETWORK_FAIL
        fi
        sleep $((2 ** attempt))
    done
}

# Updated run_orchat to accept payload instead of prompt
run_orchat() {
    local payload="$1"
    
    # Validate we have what we need
    if [ -z "$OPENROUTER_API_KEY" ]; then
        echo "[ERROR] No API key configured" >&2
        return 1
    fi
    
    response="$(_http_post "$payload")" || exit 3  # E_NETWORK_FAIL
    
    # Parse and clean response
    if echo "$response" | jq -e '.choices[0].message.content' >/dev/null 2>&1; then
        echo "$response" | jq -r '.choices[0].message.content'
    else
        echo "[ERROR] API response parsing failed" >&2
        echo "[ERROR] Response: $response" >&2
        return 1
    fi
}

# Updated streaming version
run_orchat_stream() {
    local payload="$1"
    
    # Validate we have what we need
    if [ -z "$OPENROUTER_API_KEY" ]; then
        echo "[ERROR] No API key configured" >&2
        return 1
    fi
    
    # use --no-buffer / -N and process chunks line by line
    curl --no-buffer -sS -X POST "$ORCHAT_API_URL" \
        -H "Authorization: Bearer $OPENROUTER_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>/dev/null | while IFS= read -r line; do
        if [[ $line == data:* ]]; then
            local data="${line#data: }"
            if [ "$data" != "[DONE]" ]; then
                local content=$(echo "$data" | jq -r '.choices[0].delta.content // empty' 2>/dev/null)
                if [ -n "$content" ]; then
                    printf "%s" "$content"
                fi
            fi
        fi
    done
    
    echo ""  # Newline after streaming
}
