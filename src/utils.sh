#!/usr/bin/env bash
set -euo pipefail

log_debug() { [[ "${ORCHAT_DEBUG:-}" == "1" ]] && echo "[DEBUG] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }
log_info() { echo "$*"; }

mktempfile() {
    tmpf=$(mktemp "${TMPDIR:-/tmp}/orchat.XXXXXX") || { log_error "failed create tmp"; exit 7; }
    echo "$tmpf"
}

# PROPER JSON ESCAPING - returns UNQUOTED escaped string
escape_json_string() {
    local text="$1"
    
    # Use Python3 if available (most reliable)
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import json, sys; print(json.dumps(sys.argv[1])[1:-1])" "$text"
    elif command -v python >/dev/null 2>&1; then
        python -c "import json, sys; print(json.dumps(sys.argv[1])[1:-1])" "$text"
    else
        # Basic fallback (not perfect but works for simple text)
        echo "$text" | sed \
            -e 's/\\/\\\\/g' \
            -e 's/"/\\"/g' \
            -e 's/\//\\\//g'
    fi
}
