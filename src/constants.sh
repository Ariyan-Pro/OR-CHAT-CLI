#!/usr/bin/env bash
# shellcheck disable=SC2034
ORCHAT_API_URL="https://openrouter.ai/api/v1/chat/completions"
DEFAULT_MODEL="${ORCHAT_MODEL:-openai/gpt-3.5-turbo}"  # CHANGED: Use WORKING model
DEFAULT_TEMPERATURE="0.7"
DEFAULT_HISTORY_FILE="$HOME/.orchat_history"
DEFAULT_CONFIG_FILE="$HOME/.orchatrc"
VERSION="0.2.0"

# Exit codes
E_OK=0
E_KEY_MISSING=1
E_INPUT_MISSING=2
E_NETWORK_FAIL=3
E_API_FAIL=4
E_PARSE_FAIL=5
E_RATE_LIMIT=6
E_INTERNAL=7
