#!/usr/bin/env bash
set -eo pipefail

CURL_OPTS=(-sS --fail --show-error --max-time 30)

# ============================================================================
# RATE LIMITING CONFIGURATION
# Prevents API abuse and respects OpenRouter rate limits
# ============================================================================
readonly ORCHAT_RATE_LIMIT_MAX_REQUESTS="${ORCHAT_RATE_LIMIT_MAX_REQUESTS:-10}"      # Max requests per window
readonly ORCHAT_RATE_LIMIT_WINDOW_SEC="${ORCHAT_RATE_LIMIT_WINDOW_SEC:-60}"          # Time window in seconds

# Internal state for rate limiting (indexed arrays, not associative)
declare -ga __RATE_LIMIT_TIMESTAMPS=()   # Store timestamps of recent requests
declare -g __RATE_LIMIT_ENABLED="${ORCHAT_RATE_LIMIT_ENABLED:-true}"

# ============================================================================
# RATE LIMITING FUNCTIONS
# ============================================================================

# Check if rate limit is exceeded before making a request
# Returns 0 if OK to proceed, 1 if rate limited
_check_rate_limit() {
    local current_time
    current_time=$(date +%s)
    local window_start=$((current_time - ORCHAT_RATE_LIMIT_WINDOW_SEC))
    
    # Clean old timestamps outside the window
    local cleaned_timestamps=()
    if [[ ${#__RATE_LIMIT_TIMESTAMPS[@]} -gt 0 ]]; then
        for ts in "${__RATE_LIMIT_TIMESTAMPS[@]}"; do
            if [[ $ts -ge $window_start ]]; then
                cleaned_timestamps+=("$ts")
            fi
        done
        __RATE_LIMIT_TIMESTAMPS=("${cleaned_timestamps[@]}")
    else
        __RATE_LIMIT_TIMESTAMPS=()
    fi
    
    # Check if we've exceeded the limit
    local request_count=${#__RATE_LIMIT_TIMESTAMPS[@]}
    if [[ $request_count -ge $ORCHAT_RATE_LIMIT_MAX_REQUESTS ]]; then
        return 1  # Rate limit exceeded
    fi
    
    return 0  # OK to proceed
}

# Record a request timestamp for rate limiting
_record_request() {
    local current_time
    current_time=$(date +%s)
    __RATE_LIMIT_TIMESTAMPS+=("$current_time")
}

# Get current rate limit status
get_rate_limit_status() {
    local current_time
    current_time=$(date +%s)
    local window_start=$((current_time - ORCHAT_RATE_LIMIT_WINDOW_SEC))
    
    # Count requests in current window
    local count=0
    for ts in "${__RATE_LIMIT_TIMESTAMPS[@]:-}"; do
        if [[ $ts -ge $window_start ]]; then
            ((count++))
        fi
    done
    
    local remaining=$((ORCHAT_RATE_LIMIT_MAX_REQUESTS - count))
    [[ $remaining -lt 0 ]] && remaining=0
    
    echo "requests_in_window=$count"
    echo "max_requests=$ORCHAT_RATE_LIMIT_MAX_REQUESTS"
    echo "remaining=$remaining"
    echo "window_seconds=$ORCHAT_RATE_LIMIT_WINDOW_SEC"
}

# Wait until rate limit allows a new request
_wait_for_rate_limit() {
    local max_wait="${1:-300}"  # Maximum wait time (default 5 minutes)
    local waited=0
    
    while ! _check_rate_limit; do
        if [[ $waited -ge $max_wait ]]; then
            echo "[ERROR] Rate limit wait timeout ($max_wait seconds)" >&2
            return 1
        fi
        
        # Calculate how long to wait
        local oldest_ts=${__RATE_LIMIT_TIMESTAMPS[0]:-$(date +%s)}
        local current_time
        current_time=$(date +%s)
        local age=$((current_time - oldest_ts))
        local wait_time=$((ORCHAT_RATE_LIMIT_WINDOW_SEC - age + 1))
        
        [[ $wait_time -lt 1 ]] && wait_time=1
        [[ $wait_time -gt 10 ]] && wait_time=10  # Cap individual waits at 10 seconds
        
        sleep "$wait_time"
        waited=$((waited + wait_time))
    done
    
    return 0
}

# small retry mechanism with rate limiting
_http_post() {
    local data="$1"
    local attempt=0
    local max=2
    local resp
    
    # Check rate limit before making request
    if [[ "$__RATE_LIMIT_ENABLED" == "true" ]]; then
        if ! _check_rate_limit; then
            echo "[WARNING] Rate limit exceeded. Waiting..." >&2
            if ! _wait_for_rate_limit; then
                echo "[ERROR] Rate limit timeout exceeded" >&2
                return 44  # E_API_RATE_LIMIT
            fi
        fi
    fi
    
    while true; do
        # Record this request for rate limiting
        if [[ "$__RATE_LIMIT_ENABLED" == "true" ]]; then
            _record_request
        fi
        
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
            echo "[ERROR] Network or API error occurred" >&2
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
        echo "[ERROR] Authentication credential not configured" >&2
        return 1
    fi
    
    response="$(_http_post "$payload")" || exit 3  # E_NETWORK_FAIL
    
    # Parse and clean response - generic error messages only
    if echo "$response" | jq -e '.choices[0].message.content' >/dev/null 2>&1; then
        echo "$response" | jq -r '.choices[0].message.content'
    else
        echo "[ERROR] Failed to process API response" >&2
        return 1
    fi
}

# Updated streaming version with rate limiting
run_orchat_stream() {
    local payload="$1"
    
    # Validate we have what we need
    if [ -z "$OPENROUTER_API_KEY" ]; then
        echo "[ERROR] Authentication credential not configured" >&2
        return 1
    fi
    
    # Check rate limit before making request (same as non-streaming)
    if [[ "$__RATE_LIMIT_ENABLED" == "true" ]]; then
        if ! _check_rate_limit; then
            echo "[WARNING] Rate limit exceeded. Waiting..." >&2
            if ! _wait_for_rate_limit; then
                echo "[ERROR] Rate limit timeout exceeded" >&2
                return 44  # E_API_RATE_LIMIT
            fi
        fi
        # Record this request for rate limiting
        _record_request
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
