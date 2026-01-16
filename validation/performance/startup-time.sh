#!/usr/bin/env bash
# Startup Time Performance Validation
# 50+ Years Standard: Measurable, consistent performance metrics

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
MEASUREMENTS=()

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
        INFO) echo -e "${BLUE}ℹ INFO${NC} $test_name: $message" ;;
    esac
}

measure_command() {
    local command_name="$1"
    shift
    local command_args="$*"
    
    echo "Measuring: orchat $command_args"
    
    # Run warm-up
    orchat --help >/dev/null 2>&1
    
    # Measure multiple times
    local -a times=()
    for i in {1..5}; do
        local start_time
        start_time=$(date +%s%N)
        
        eval "orchat $command_args >/dev/null 2>&1"
        
        local end_time
        end_time=$(date +%s%N)
        local duration=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds
        
        times+=("$duration")
        echo "  Run $i: ${duration}ms"
        
        # Small delay between runs
        sleep 0.1
    done
    
    # Calculate statistics
    local sum=0
    local min=999999
    local max=0
    
    for t in "${times[@]}"; do
        sum=$((sum + t))
        if [[ $t -lt $min ]]; then min=$t; fi
        if [[ $t -gt $max ]]; then max=$t; fi
    done
    
    local avg=$((sum / ${#times[@]}))
    
    # Store measurement
    MEASUREMENTS+=("$command_name: avg=${avg}ms, min=${min}ms, max=${max}ms")
    
    print_result "Performance: $command_name" "INFO" "avg=${avg}ms, min=${min}ms, max=${max}ms"
    
    # Check against SLA (example: help should be < 500ms)
    case "$command_name" in
        "help")
            if [[ $avg -lt 500 ]]; then
                print_result "SLA: $command_name" "PASS" "avg ${avg}ms < 500ms"
            else
                print_result "SLA: $command_name" "FAIL" "avg ${avg}ms ≥ 500ms"
            fi
            ;;
        "version")
            if [[ $avg -lt 300 ]]; then
                print_result "SLA: $command_name" "PASS" "avg ${avg}ms < 300ms"
            else
                print_result "SLA: $command_name" "FAIL" "avg ${avg}ms ≥ 300ms"
            fi
            ;;
        "config_show")
            if [[ $avg -lt 800 ]]; then
                print_result "SLA: $command_name" "PASS" "avg ${avg}ms < 800ms"
            else
                print_result "SLA: $command_name" "FAIL" "avg ${avg}ms ≥ 800ms"
            fi
            ;;
    esac
}

test_cold_start() {
    print_header "1. COLD START PERFORMANCE"
    
    echo "Clearing caches for cold start test..."
    
    # Clear shell hash cache
    hash -r 2>/dev/null || true
    
    # Clear any ORCHAT caches
    rm -f ~/.cache/orchat/* 2>/dev/null || true
    
    # Measure cold start
    local start_time
    start_time=$(date +%s%N)
    
    # First run after cache clear
    orchat --help >/dev/null 2>&1
    
    local end_time
    end_time=$(date +%s%N)
    local cold_start=$(( (end_time - start_time) / 1000000 ))
    
    print_result "Cold start" "INFO" "First run: ${cold_start}ms"
    
    if [[ $cold_start -lt 1000 ]]; then
        print_result "Cold start SLA" "PASS" "${cold_start}ms < 1000ms"
    else
        print_result "Cold start SLA" "FAIL" "${cold_start}ms ≥ 1000ms"
    fi
}

test_warm_start() {
    print_header "2. WARM START PERFORMANCE"
    
    echo "Testing warm start (cached) performance..."
    
    # Run warm-up
    orchat --help >/dev/null 2>&1
    orchat --version >/dev/null 2>&1
    
    measure_command "help" "--help"
    measure_command "version" "--version"
    measure_command "config_show" "config show"
}

test_memory_usage() {
    print_header "3. MEMORY USAGE DURING STARTUP"
    
    echo "Measuring memory footprint..."
    
    # Measure memory usage of help command
    /usr/bin/time -f "Memory: %M KB (max RSS)" orchat --help >/dev/null 2>&1 2>/tmp/orchat-mem.txt || true
    
    local mem_usage
    mem_usage=$(grep "Memory:" /tmp/orchat-mem.txt | awk '{print $2}' || echo "0")
    
    if [[ -n "$mem_usage" ]] && [[ "$mem_usage" != "0" ]]; then
        print_result "Memory usage" "INFO" "${mem_usage}KB RSS"
        
        # Check against limit (example: < 50MB)
        if [[ $mem_usage -lt 50000 ]]; then
            print_result "Memory SLA" "PASS" "${mem_usage}KB < 50000KB"
        else
            print_result "Memory SLA" "FAIL" "${mem_usage}KB ≥ 50000KB"
        fi
    fi
    
    rm -f /tmp/orchat-mem.txt
}

test_concurrent_starts() {
    print_header "4. CONCURRENT STARTUP PERFORMANCE"
    
    echo "Testing 5 concurrent startups..."
    
    local start_time
    start_time=$(date +%s%N)
    
    # Start 5 instances concurrently
    for i in {1..5}; do
        (orchat --help >/dev/null 2>&1) &
    done
    
    # Wait for all
    wait
    
    local end_time
    end_time=$(date +%s%N)
    local concurrent_time=$(( (end_time - start_time) / 1000000 ))
    
    print_result "Concurrent startups" "INFO" "5 instances: ${concurrent_time}ms"
    
    if [[ $concurrent_time -lt 2000 ]]; then
        print_result "Concurrent SLA" "PASS" "${concurrent_time}ms < 2000ms"
    else
        print_result "Concurrent SLA" "FAIL" "${concurrent_time}ms ≥ 2000ms"
    fi
}

generate_report() {
    print_header "PERFORMANCE VALIDATION REPORT"
    
    echo "=== STARTUP TIME PERFORMANCE ==="
    echo "Generated: $(date)"
    echo "Host: $(hostname)"
    echo "ORCHAT Version: $(orchat --version 2>/dev/null | head -1 || echo "Unknown")"
    echo ""
    
    echo "=== MEASUREMENTS ==="
    for measurement in "${MEASUREMENTS[@]}"; do
        echo "  $measurement"
    done
    
    echo ""
    echo "=== PERFORMANCE SLAs ==="
    echo "1. Cold start: < 1000ms"
    echo "2. Help command: < 500ms"
    echo "3. Version command: < 300ms"
    echo "4. Config show: < 800ms"
    echo "5. Memory usage: < 50MB RSS"
    echo "6. Concurrent (5x): < 2000ms"
    echo ""
    
    echo "=== RECOMMENDATIONS ==="
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "✅ All performance SLAs met"
    else
        echo "⚠️  $TESTS_FAILED SLA(s) failed"
        echo "Consider:"
        echo "  - Optimizing module loading"
        echo "  - Implementing lazy initialization"
        echo "  - Adding caching for config/state"
    fi
}

main() {
    print_header "STARTUP TIME PERFORMANCE VALIDATION"
    echo "Establishing performance baseline for ORCHAT Enterprise"
    echo ""
    
    # Verify ORCHAT is installed
    if ! command -v orchat >/dev/null 2>&1; then
        echo -e "${RED}❌ ORCHAT not found in PATH${NC}"
        echo "Install ORCHAT before running performance tests"
        exit 1
    fi
    
    test_cold_start
    test_warm_start
    test_memory_usage
    test_concurrent_starts
    generate_report
    
    # Summary
    print_header "VALIDATION SUMMARY"
    echo "Tests Run:    $TESTS_RUN"
    echo "Tests Passed: $TESTS_PASSED"
    echo "Tests Failed: $TESTS_FAILED"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✅ PERFORMANCE VALIDATION PASSED${NC}"
        echo "All performance SLAs met"
        exit 0
    else
        echo -e "${YELLOW}⚠ PERFORMANCE VALIDATION HAS FAILURES${NC}"
        echo "$TESTS_FAILED SLA(s) not met - see recommendations"
        exit 1
    fi
}

main "$@"
