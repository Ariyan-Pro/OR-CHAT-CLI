#!/usr/bin/env bats

setup() {
    export ORCHAT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" && pwd)"
    source "$ORCHAT_ROOT/src/payload.sh"
}

@test "payload_build creates valid JSON" {
    local messages='[{"role": "user", "content": "Hello"}]'
    local payload
    payload=$(payload_build "$messages" "test-model" 0.7 "false")
    
    # Should be valid JSON
    echo "$payload" | python3 -c "import json,sys; json.load(sys.stdin)"
    [ $? -eq 0 ]
}

@test "payload_build includes temperature" {
    local messages='[{"role": "user", "content": "Hello"}]'
    local payload
    payload=$(payload_build "$messages" "test-model" 1.5 "false")
    
    echo "$payload" | grep -q '"temperature":1.5'
}
