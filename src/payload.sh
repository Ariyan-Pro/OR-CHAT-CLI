#!/usr/bin/env bash

payload_build() {
    local messages_json="$1"
    local model="${2:-${RESOLVED_MODEL:-openai/gpt-3.5-turbo}}"
    local temperature="${3:-${RESOLVED_TEMPERATURE:-0.7}}"
    local max_tokens="${4:-${RESOLVED_MAX_TOKENS:-1000}}"
    local stream="${5:-false}"
    
    # Convert stream boolean to JSON true/false
    local stream_json="false"
    if [[ "$stream" == "true" ]]; then
        stream_json="true"
    fi
    
    # Build JSON payload
    cat <<EOF
{
  "model": "$model",
  "messages": $messages_json,
  "temperature": $temperature,
  "max_tokens": $max_tokens,
  "stream": $stream_json
}
EOF
}

# If called directly, test the function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    payload_build "$@"
fi
