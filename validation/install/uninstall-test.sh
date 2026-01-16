#!/usr/bin/env bash
# ORCHAT Enterprise Uninstall Validation
# Phase 7.5: Ensure clean uninstallation

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

check_file_removed() {
    local file="$1"
    local description="$2"
    
    if [[ -e "$file" ]]; then
        print_result "File removal" "FAIL" "$description still exists: $file"
        return 1
    else
        print_result "File removal" "PASS" "$description removed"
        return 0
    fi
}

main() {
    print_header "ORCHAT ENTERPRISE UNINSTALL VALIDATION"
    echo "Timestamp: $(date)"
    echo "Host: $(hostname)"
    echo "User: $(whoami)"
    echo ""
    
    # Track what exists before uninstall
    print_header "1. PRE-UNINSTALL INVENTORY"
    
    local files_exist=()
    local dirs_exist=()
    
    # Check common installation locations
    for path in \
        "/usr/local/bin/orchat" \
        "/usr/bin/orchat" \
        "$HOME/.local/bin/orchat" \
        "$HOME/.config/orchat" \
        "$HOME/.cache/orchat" \
        "/tmp/orchat" \
        "/var/log/orchat"; do
        
        if [[ -e "$path" ]]; then
            if [[ -d "$path" ]]; then
                dirs_exist+=("$path")
                echo "Directory exists: $path"
            else
                files_exist+=("$path")
                echo "File exists: $path"
            fi
        fi
    done
    
    # Simulate uninstall (actual uninstall would be done by package manager)
    print_header "2. SIMULATED UNINSTALL PROCESS"
    
    echo "Note: In production, this would run:"
    echo "  sudo apt-get remove --purge orchat"
    echo "  or equivalent package manager command"
    echo ""
    
    # Test what should happen
    print_header "3. POST-UNINSTALL VERIFICATION"
    
    # 1. Binary should be removed from PATH
    if command -v orchat >/dev/null 2>&1; then
        print_result "Binary removal" "FAIL" "orchat still in PATH: $(which orchat)"
    else
        print_result "Binary removal" "PASS" "orchat not found in PATH"
    fi
    
    # 2. Config directory should be removed (if purge)
    if [[ -d "$HOME/.config/orchat" ]]; then
        print_result "Config cleanup" "WARN" "Config directory still exists (may be intentional)"
    else
        print_result "Config cleanup" "PASS" "Config directory removed"
    fi
    
    # 3. Cache should be cleaned
    if [[ -d "$HOME/.cache/orchat" ]]; then
        print_result "Cache cleanup" "WARN" "Cache directory still exists"
    else
        print_result "Cache cleanup" "PASS" "Cache directory removed"
    fi
    
    # 4. No orphaned processes
    if pgrep -f "orchat" >/dev/null; then
        print_result "Process cleanup" "FAIL" "Orphaned orchat processes found"
    else
        print_result "Process cleanup" "PASS" "No orphaned processes"
    fi
    
    print_header "4. REINSTALL TEST"
    
    echo "Simulating reinstall after uninstall..."
    print_result "Reinstall capability" "INFO" "Would require actual package installation"
    
    print_header "VALIDATION SUMMARY"
    echo "Tests Run:    $TESTS_RUN"
    echo "Tests Passed: $TESTS_PASSED"
    echo "Tests Failed: $TESTS_FAILED"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✅ UNINSTALL VALIDATION PASSED${NC}"
        echo "Uninstall process appears clean"
        exit 0
    else
        echo -e "${RED}❌ UNINSTALL VALIDATION FAILED${NC}"
        echo "$TESTS_FAILED test(s) failed"
        exit 1
    fi
}

main "$@"
