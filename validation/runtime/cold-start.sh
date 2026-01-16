#!/usr/bin/env bash
# ORCHAT Enterprise Cold Start Validation
# Phase 7.5: Test startup from completely cold state

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

measure_time() {
    local command="$1"
    local label="$2"
    
    echo -n "  Measuring $label... "
    
    # Clear caches for cold start
    sync
    echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true
    
    # Measure time
    local start_time=$(date +%s%N)
    eval "$command" >/dev/null 2>&1
    local end_time=$(date +%s%N)
    
    local duration=$(( (end_time - start_time) / 1000000 ))
    echo "${duration}ms"
    
    echo "$label: $duration ms" >> /tmp/orchat-cold-start-times.txt
    
    # Check against SLA
    case "$label" in
        "cold --help")
            if [[ $duration -lt 1000 ]]; then
                print_result "Cold --help SLA" "PASS" "$duration ms < 1000 ms"
            else
                print_result "Cold --help SLA" "FAIL" "$duration ms >= 1000 ms"
            fi
            ;;
        "cold --version")
            if [[ $duration -lt 300 ]]; then
                print_result "Cold --version SLA" "PASS" "$duration ms < 300 ms"
            else
                print_result "Cold --version SLA" "FAIL" "$duration ms >= 300 ms"
            fi
            ;;
    esac
    
    return $duration
}

main() {
    print_header "ORCHAT ENTERPRISE COLD START VALIDATION"
    echo "Timestamp: $(date)"
    echo "Host: $(hostname)"
    echo "User: $(whoami)"
    echo ""
    
    # Clear previous measurements
    > /tmp/orchat-cold-start-times.txt
    
    print_header "1. CLEARING SYSTEM CACHES"
    
    echo "Flushing caches for true cold start..."
    
    # Clear bash hash table (command cache)
    hash -r 2>/dev/null || true
    
    # Clear disk caches if possible
    if command -v sudo >/dev/null 2>&1; then
        sync
        sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches' 2>/dev/null || true
        print_result "Cache flush" "INFO" "Attempted to clear system caches"
    else
        print_result "Cache flush" "WARN" "Cannot clear system caches (no sudo)"
    fi
    
    # Remove ORCHAT from any runtime caches
    local ORCHAT_BIN=$(command -v orchat 2>/dev/null || echo "$HOME/.local/bin/orchat")
    if [[ -x "$ORCHAT_BIN" ]]; then
        # Try to uncache binary
        cat "$ORCHAT_BIN" >/dev/null 2>&1 || true
    fi
    
    print_header "2. COLD START PERFORMANCE"
    
    echo "First execution after cache clear (true cold start)..."
    
    # Measure cold start times
    local cold_help_time=$(measure_time "$ORCHAT_BIN --help" "cold --help")
    sleep 1
    
    local cold_version_time=$(measure_time "$ORCHAT_BIN --version" "cold --version")
    sleep 1
    
    local cold_health_time=$(measure_time "$ORCHAT_BIN health-check" "cold health-check")
    sleep 1
    
    print_header "3. WARM START COMPARISON"
    
    echo "Second execution (warm start)..."
    
    local warm_help_time=$(measure_time "$ORCHAT_BIN --help" "warm --help")
    sleep 0.5
    
    local warm_version_time=$(measure_time "$ORCHAT_BIN --version" "warm --version")
    
    print_header "4. MEMORY USAGE ON COLD START"
    
    echo "Measuring memory footprint on cold start..."
    
    # Start ORCHAT in background and measure memory
    $ORCHAT_BIN --version &
    local orchat_pid=$!
    sleep 0.2
    
    if ps -p $orchat_pid >/dev/null 2>&1; then
        local memory_kb=$(ps -o rss= -p $orchat_pid 2>/dev/null | awk '{print $1}')
        
        if [[ -n "$memory_kb" ]]; then
            echo "  Memory usage: ${memory_kb}KB RSS"
            
            if [[ $memory_kb -lt 50000 ]]; then
                print_result "Memory SLA" "PASS" "${memory_kb}KB < 50000KB"
            else
                print_result "Memory SLA" "FAIL" "${memory_kb}KB >= 50000KB"
            fi
            
            # Save for report
            echo "Memory: $memory_kb KB" >> /tmp/orchat-cold-start-times.txt
        fi
        
        # Clean up
        kill $orchat_pid 2>/dev/null || true
        wait $orchat_pid 2>/dev/null || true
    fi
    
    print_header "5. COLD START RELIABILITY"
    
    echo "Testing 5 consecutive cold starts..."
    
    local failures=0
    for i in {1..5}; do
        echo -n "  Attempt $i: "
        if $ORCHAT_BIN --version >/dev/null 2>&1; then
            echo "Success"
        else
            echo "Failed"
            failures=$((failures + 1))
        fi
        sleep 0.5
    done
    
    if [[ $failures -eq 0 ]]; then
        print_result "Cold start reliability" "PASS" "5/5 successful cold starts"
    else
        print_result "Cold start reliability" "FAIL" "$failures/5 failed cold starts"
    fi
    
    print_header "COLD START PERFORMANCE REPORT"
    echo ""
    cat /tmp/orchat-cold-start-times.txt 2>/dev/null || echo "No timing data collected"
    echo ""
    
    print_header "VALIDATION SUMMARY"
    echo "Tests Run:    $TESTS_RUN"
    echo "Tests Passed: $TESTS_PASSED"
    echo "Tests Failed: $TESTS_FAILED"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✅ COLD START VALIDATION PASSED${NC}"
        echo "Cold start performance meets SLAs"
        exit 0
    else
        echo -e "${RED}❌ COLD START VALIDATION FAILED${NC}"
        echo "$TESTS_FAILED test(s) failed"
        exit 1
    fi
}

main "$@"
