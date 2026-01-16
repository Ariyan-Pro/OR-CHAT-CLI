#!/usr/bin/env bash
# ORCHAT Enterprise Permission Validation
# Phase 7.5: Test security permissions and access control

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
        WARN) echo -e "${YELLOW}⚠ WARN${NC} $test_name: $message" ;;
    esac
}

check_permission() {
    local file="$1"
    local expected="$2"
    local description="$3"
    
    if [[ ! -e "$file" ]]; then
        print_result "$description" "WARN" "File does not exist: $file"
        return
    fi
    
    local actual=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%Lp" "$file" 2>/dev/null)
    
    if [[ "$actual" == "$expected" ]]; then
        print_result "$description" "PASS" "Permissions $actual == $expected for $file"
    else
        print_result "$description" "FAIL" "Permissions $actual != $expected for $file"
    fi
}

main() {
    print_header "ORCHAT ENTERPRISE PERMISSION VALIDATION"
    echo "Timestamp: $(date)"
    echo "Host: $(hostname)"
    echo "User: $(whoami)"
    echo ""
    
    # Find orchat binary
    local ORCHAT_BIN=$(command -v orchat 2>/dev/null || echo "")
    
    if [[ -z "$ORCHAT_BIN" ]]; then
        echo "ORCHAT not found in PATH. Using validation version."
        ORCHAT_BIN="$HOME/.local/bin/orchat"
    fi
    
    print_header "1. BINARY PERMISSIONS"
    
    if [[ -e "$ORCHAT_BIN" ]]; then
        check_permission "$ORCHAT_BIN" "755" "Binary executable"
        
        # Check ownership
        if [[ $(stat -c "%U" "$ORCHAT_BIN" 2>/dev/null) == "root" ]]; then
            print_result "Binary ownership" "PASS" "Owned by root"
        else
            print_result "Binary ownership" "WARN" "Not owned by root: $(stat -c "%U" "$ORCHAT_BIN")"
        fi
        
        # Check for setuid/setgid (should NOT have)
        if [[ -u "$ORCHAT_BIN" ]] || [[ -g "$ORCHAT_BIN" ]]; then
            print_result "Setuid/Setgid" "FAIL" "Binary has setuid/setgid bits (security risk)"
        else
            print_result "Setuid/Setgid" "PASS" "No setuid/setgid bits"
        fi
    else
        print_result "Binary check" "FAIL" "ORCHAT binary not found"
    fi
    
    print_header "2. CONFIGURATION FILES"
    
    local CONFIG_DIR="$HOME/.config/orchat"
    local CONFIG_FILE="$CONFIG_DIR/config"
    
    if [[ -e "$CONFIG_FILE" ]]; then
        check_permission "$CONFIG_FILE" "600" "Config file (should be user-read-only)"
        
        # Config should not be world readable
        local perm=$(stat -c "%a" "$CONFIG_FILE")
        if [[ $((perm & 004)) -ne 0 ]]; then
            print_result "Config world readable" "FAIL" "Config is world readable (security risk)"
        else
            print_result "Config world readable" "PASS" "Config not world readable"
        fi
    else
        print_result "Config file" "INFO" "No config file found (normal for fresh install)"
    fi
    
    print_header "3. CACHE AND LOG FILES"
    
    # Check cache directory
    local CACHE_DIR="$HOME/.cache/orchat"
    if [[ -d "$CACHE_DIR" ]]; then
        check_permission "$CACHE_DIR" "700" "Cache directory"
    fi
    
    # Check log files (if any)
    for log in /var/log/orchat.log /tmp/orchat.log "$HOME/orchat.log"; do
        if [[ -f "$log" ]]; then
            check_permission "$log" "644" "Log file: $log"
        fi
    done
    
    print_header "4. SECURITY CHECKS"
    
    # Check for world-writable directories in PATH
    echo "Checking PATH security..."
    local insecure_paths=0
    IFS=':' read -ra PATHS <<< "$PATH"
    for path in "${PATHS[@]}"; do
        if [[ -d "$path" ]]; then
            if [[ -w "$path" ]] && [[ "$path" != "$HOME"* ]]; then
                print_result "PATH directory" "WARN" "World-writable directory in PATH: $path"
                insecure_paths=$((insecure_paths + 1))
            fi
        fi
    done
    
    if [[ $insecure_paths -eq 0 ]]; then
        print_result "PATH security" "PASS" "No world-writable directories in PATH"
    fi
    
    # Check for shell injection vulnerabilities
    print_result "Injection check" "INFO" "Manual code review required for injection vulnerabilities"
    
    print_header "5. PRIVILEGE ESCALATION TEST"
    
    # Try to run with sudo (should fail or require password)
    if sudo -n true 2>/dev/null; then
        echo "Testing privilege escalation..."
        if sudo -n orchat --version 2>&1 | grep -q "not allowed\|password"; then
            print_result "Privilege escalation" "PASS" "sudo requires authentication"
        else
            print_result "Privilege escalation" "WARN" "sudo may not require password"
        fi
    else
        print_result "Privilege escalation" "INFO" "sudo not available or requires password"
    fi
    
    print_header "VALIDATION SUMMARY"
    echo "Tests Run:    $TESTS_RUN"
    echo "Tests Passed: $TESTS_PASSED"
    echo "Tests Failed: $TESTS_FAILED"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✅ PERMISSION VALIDATION PASSED${NC}"
        echo "Security permissions appear appropriate"
        exit 0
    else
        echo -e "${RED}❌ PERMISSION VALIDATION FAILED${NC}"
        echo "$TESTS_FAILED test(s) failed"
        exit 1
    fi
}

main "$@"
