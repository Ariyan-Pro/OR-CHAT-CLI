#!/usr/bin/env bats

setup() {
    export ORCHAT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" && pwd)"
    
    # Load Phase 3 modules
    source "$ORCHAT_ROOT/src/constants.sh"
    source "$ORCHAT_ROOT/src/history.sh"
    source "$ORCHAT_ROOT/src/context.sh"
    source "$ORCHAT_ROOT/src/payload.sh"
    
    # Test directory
    export TEST_DIR="$(mktemp -d)"
    export ORCHAT_HISTORY_DIR="$TEST_DIR"
    export MAX_HISTORY_LENGTH=5
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "history_init creates valid JSON file" {
    run history_init "test_session"
    [ "$status" -eq 0 ]
    [ -f "$output" ]
    
    # Check file contains valid JSON array
    run jq -e '. | type == "array"' "$output"
    [ "$status" -eq 0 ]
}

@test "history_add appends messages correctly" {
    local session_file
    session_file=$(history_init "test_session")
    
    history_add "$session_file" "user" "Hello there"
    history_add "$session_file" "assistant" "Hi! How can I help?"
    
    run history_length "$session_file"
    [ "$status" -eq 0 ]
    [ "$output" -eq 2 ]
    
    # Verify content
    run history_dump_as_json_array "$session_file"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.[0].role == "user" and .[0].content == "Hello there"' >/dev/null
    echo "$output" | jq -e '.[1].role == "assistant" and .[1].content == "Hi! How can I help?"' >/dev/null
}

@test "history_get_messages trims correctly" {
    local session_file
    session_file=$(history_init "test_session")
    
    # Add 10 messages
    for i in {1..10}; do
        history_add "$session_file" "user" "Message $i"
        history_add "$session_file" "assistant" "Response $i"
    done
    
    # Get with limit of 5
    run history_get_messages "$session_file" 5
    [ "$status" -eq 0 ]
    
    local count
    count=$(echo "$output" | jq 'length')
    [ "$count" -eq 5 ]
}

@test "build_message_stack with system prompt" {
    local system="You are a helpful assistant."
    local user="What is 2+2?"
    
    run build_message_stack "$system" "$user" "[]"
    [ "$status" -eq 0 ]
    
    echo "$output" | jq -e '.[0].role == "system"' >/dev/null
    echo "$output" | jq -e '.[0].content == "You are a helpful assistant."' >/dev/null
    echo "$output" | jq -e '.[1].role == "user"' >/dev/null
}

@test "build_message_stack with history" {
    local history='[
      {"role": "user", "content": "Hello"},
      {"role": "assistant", "content": "Hi there"}
    ]'
    
    run build_message_stack "" "Second message" "$history"
    [ "$status" -eq 0 ]
    
    local count
    count=$(echo "$output" | jq 'length')
    [ "$count" -eq 3 ]
    
    echo "$output" | jq -e '.[0].role == "user" and .[0].content == "Hello"' >/dev/null
    echo "$output" | jq -e '.[2].role == "user" and .[2].content == "Second message"' >/dev/null
}

@test "trim_context reduces message count" {
    local messages='[
      {"role": "system", "content": "You are helpful"},
      {"role": "user", "content": "Message 1"},
      {"role": "assistant", "content": "Response 1"},
      {"role": "user", "content": "Message 2"},
      {"role": "assistant", "content": "Response 2"},
      {"role": "user", "content": "Message 3"}
    ]'
    
    # Trim to 100 characters (will remove some messages)
    run trim_context "$messages" 100
    [ "$status" -eq 0 ]
    
    local trimmed_count
    trimmed_count=$(echo "$output" | jq 'length')
    [ "$trimmed_count" -lt 6 ]
    
    # System message should be preserved
    echo "$output" | jq -e '.[0].role == "system"' >/dev/null
}

@test "payload_build creates valid JSON" {
    local messages='[{"role": "user", "content": "test"}]'
    
    run payload_build "$messages" "test-model" 0.7 "false"
    [ "$status" -eq 0 ]
    
    # Validate JSON structure
    echo "$output" | jq -e '.model == "test-model"' >/dev/null
    echo "$output" | jq -e '.temperature == 0.7' >/dev/null
    echo "$output" | jq -e '.stream == false' >/dev/null
    echo "$output" | jq -e '.messages[0].content == "test"' >/dev/null
}

@test "payload_validate detects invalid payload" {
    local valid_payload='{"model":"test","messages":[{"role":"user","content":"test"}],"temperature":0.7,"stream":false}'
    local invalid_payload='{"model":"test","messages":[],"temperature":0.7,"stream":false}'
    
    run payload_validate "$valid_payload"
    [ "$output" = "VALID" ]
    
    run payload_validate "$invalid_payload"
    [ "$output" != "VALID" ]
}
