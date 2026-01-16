#!/usr/bin/env bash
# No API Key Runtime Validation
# 50+ Years Standard: Graceful degradation, not crashes

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_result() {
    local test_name="$1"
    local status="$2"
    local message="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    case "$status" in
        PASS) echo -e "${GREEN}✓ PASS${NC} $test_name: $message"; TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
        FAIL) echo -e "${RED}✗ FAIL${NC} $test_name: $message"; TESTS_FAILED=$((TESTS_FAILED + 1)) ;;
    esac
}

cleanup_api_keys() {
    print_header "0. CLEANING API CONFIGURATION"
    
    echo "Removing all API key configurations..."
    
    # Remove config file
    rm -f ~/.config/orchat/config 2>/dev/null || true
    
    # Unset environment variables
    unset ORCHAT_API_KEY
    unset OPENROUTER_API_KEY
    unset OPENAI_API_KEY
    
    # Clear any cached credentials
    rm -f ~/.cache/orchat/* 2>/dev/null || true
    
    print_result "Cleanup" "PASS" "API configuration cleared"
}

test_simple_generation() {
    print_header "1. TESTING SIMPLE GENERATION WITHOUT KEY"
    
    echo "Command: orchat 'Hello, world!'"
    echo ""
    
    local output
    local exit_code=0
    output=$(orchat "Hello, world!" 2>&1) || exit_code=$?
    
    echo "Exit Code: $exit_code"
    echo "Output:"
    echo "----------------------------------------"
    echo "$output"
    echo "----------------------------------------"
    echo ""
    
    # Check for expected error messages
    local found_error=0
    
    # Should mention API key
    if echo "$output" | grep -qi "api.*key\|key.*missing\|key.*required\|key.*not"; then
        print_result "Clear API key error" "PASS" "Mentions API key issue"
        found_error=1
    fi
    
    # Should NOT show stack trace
    if echo "$output" | grep -qi "trace\|stack\|dump\|core\|segmentation"; then
        print_result "No stack trace" "FAIL" "Stack trace leaked"
    else
        print_result "No stack trace" "PASS" "Clean error output"
    fi
    
    # Should NOT show raw curl command
    if echo "$output" | grep -qi "curl.*https:\|http.*request\|--header"; then
        print_result "No internal details" "WARN" "Internal details exposed"
    fi
    
    # Should have non-zero exit code
    if [[ $exit_code -eq 0 ]]; then
        print_result "Non-zero exit code" "FAIL" "Exited with 0 (should fail)"
    else
        print_result "Non-zero exit code" "PASS" "Exited with $exit_code (correct)"
    fi
    
    if [[ $found_error -eq 0 ]]; then
        print_result "Error detection" "FAIL" "No clear error message"
    fi
}

test_config_commands() {
    print_header "2. TESTING CONFIG COMMANDS WITHOUT KEY"
    
    # Test config show (should work without key)
    echo "Testing: orchat config show"
    local output
    output=$(orchat config show 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        print_result "Config show" "PASS" "Works without API key"
    else
        print_result "Config show" "FAIL" "Failed with exit code $exit_code"
    fi
    
    # Test config set (should work without key)
    echo ""
    echo "Testing: orchat config set api.openrouter_api_key 'test-key-123'"
    output=$(orchat config set api.openrouter_api_key 'test-key-123' 2>&1)
    exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        print_result "Config set" "PASS" "Can set config without API key"
        
        # Verify it was saved
        if grep -q "test-key-123" ~/.config/orchat/config 2>/dev/null; then
            print_result "Config save" "PASS" "Config saved correctly"
        else
            print_result "Config save" "WARN" "Config may not have saved"
        fi
    else
        print_result "Config set" "FAIL" "Failed with exit code $exit_code"
    fi
}

test_help_commands() {
    print_header "3. TESTING HELP COMMANDS WITHOUT KEY"
    
    local -a help_commands=(
        "--help"
        "--version"
        "help"
        "config --help"
        "generate --help"
    )
    
    for cmd in "${help_commands[@]}"; do
        echo "Testing: orchat $cmd"
        if orchat $cmd 2>&1 | head -2 | grep -q -i "usage\|help\|version\|orchat"; then
            print_result "Help: $cmd" "PASS" "Works without API key"
        else
            print_result "Help: $cmd" "FAIL" "Failed: $cmd"
        fi
        echo ""
    done
}

test_enterprise_commands() {
    print_header "4. TESTING ENTERPRISE COMMANDS WITHOUT KEY"
    
    # These should work without API key
    local -a enterprise_cmds=(
        "health-check"
        "metrics"
        "status"
        "validate"
    )
    
    for cmd in "${enterprise_cmds[@]}"; do
        echo "Testing: orchat $cmd"
        local output
        output=$(timeout 5 orchat $cmd 2>&1 || true)
        
        # Check if it ran (might fail for other reasons, but shouldn't need API key)
        if echo "$output" | grep -qi "api.*key\|key.*required"; then
            print_result "Enterprise: $cmd" "FAIL" "Unexpectedly requires API key"
        else
            print_result "Enterprise: $cmd" "PASS" "Works without API key"
        fi
        echo ""
    done
}

test_error_recovery() {
    print_header "5. TESTING ERROR RECOVERY"
    
    echo "Testing: Set invalid key, then generate"
    
    # Set an invalid key
    orchat config set api.openrouter_api_key 'invalid-key-123' >/dev/null 2>&1 || true
    
    # Try to generate
    local output
    output=$(orchat "Test message" 2>&1 || true)
    
    # Should show API error, not crash
    if echo "$output" | grep -qi "invalid.*key\|auth\|401\|403"; then
        print_result "Invalid key handling" "PASS" "Properly reports invalid key"
    elif echo "$output" | grep -qi "api.*error\|failed\|error"; then
        print_result "Invalid key handling" "PASS" "Reports API error"
    else
        print_result "Invalid key handling" "FAIL" "No clear error for invalid key"
    fi
    
    # Clear the invalid key
    rm -f ~/.config/orchat/config 2>/dev/null || true
}

main() {
    print_header "NO API KEY RUNTIME VALIDATION"
    echo "Validating graceful degradation without API credentials"
    echo ""
    
    cleanup_api_keys
    
    test_simple_generation
    test_config_commands
    test_help_commands
    test_enterprise_commands
    test_error_recovery
    
    # Summary
    print_header "VALIDATION SUMMARY"
    echo "Tests Run:    $TESTS_RUN"
    echo "Tests Passed: $TESTS_PASSED"
    echo "Tests Failed: $TESTS_FAILED"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✅ NO API KEY VALIDATION PASSED${NC}"
        echo "ORCHAT handles missing API keys gracefully"
        exit 0
    else
        echo -e "${RED}❌ NO API KEY VALIDATION FAILED${NC}"
        echo "$TESTS_FAILED test(s) failed"
        exit 1
    fi
}

main "$@"
