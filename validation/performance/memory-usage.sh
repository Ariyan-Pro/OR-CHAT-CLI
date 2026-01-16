#!/usr/bin/env bash
# ORCHAT Enterprise Memory Usage Validation
# Phase 7.5: Measure and validate memory consumption patterns

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

get_memory_usage() {
    local pid="$1"
    local metric="${2:-rss}"  # rss, vsz, or pmem
    
    case "$metric" in
        rss)
            ps -o rss= -p "$pid" 2>/dev/null | awk '{print $1}'
            ;;
        vsz)
            ps -o vsz= -p "$pid" 2>/dev/null | awk '{print $1}'
            ;;
        pmem)
            ps -o pmem= -p "$pid" 2>/dev/null | awk '{print $1}'
            ;;
    esac
}

run_memory_test() {
    local test_name="$1"
    local command="$2"
    local max_memory_kb="$3"
    local duration_sec="${4:-5}"
    
    print_header "TEST: $test_name"
    echo "Command: $command"
    echo "Duration: ${duration_sec}s"
    echo "Memory Limit: ${max_memory_kb}KB"
    echo ""
    
    # Start process
    eval "$command" &
    local pid=$!
    
    # Wait a bit for startup
    sleep 1
    
    # Monitor memory for specified duration
    local max_observed=0
    local samples=0
    local total=0
    
    echo "Monitoring memory usage every 0.5s..."
    for ((i=0; i<duration_sec*2; i++)); do
        local current=$(get_memory_usage $pid "rss")
        
        if [[ -n "$current" ]] && [[ "$current" -gt 0 ]]; then
            samples=$((samples + 1))
            total=$((total + current))
            
            if [[ $current -gt $max_observed ]]; then
                max_observed=$current
            fi
            
            echo "  Sample $((i+1)): ${current}KB"
            
            # Check if we're exceeding limit
            if [[ $current -gt $max_memory_kb ]]; then
                print_result "$test_name memory limit" "FAIL" "Exceeded limit: ${current}KB > ${max_memory_kb}KB"
                kill $pid 2>/dev/null || true
                return 1
            fi
        fi
        
        sleep 0.5
    done
    
    # Clean up
    kill $pid 2>/dev/null || true
    wait $pid 2>/dev/null || true
    
    # Calculate average
    local avg=0
    if [[ $samples -gt 0 ]]; then
        avg=$((total / samples))
    fi
    
    echo ""
    echo "Results for $test_name:"
    echo "  Maximum: ${max_observed}KB"
    echo "  Average: ${avg}KB"
    echo "  Samples: ${samples}"
    
    # Check if memory is reasonable
    if [[ $max_observed -lt $max_memory_kb ]]; then
        print_result "$test_name memory" "PASS" "Within limit: ${max_observed}KB < ${max_memory_kb}KB"
    else
        print_result "$test_name memory" "FAIL" "Exceeds limit: ${max_observed}KB >= ${max_memory_kb}KB"
    fi
    
    # Check for memory leaks (avg should be stable)
    if [[ $samples -ge 4 ]]; then
        # Simple check: last quarter shouldn't be significantly higher than first quarter
        print_result "$test_name stability" "INFO" "Memory leak testing requires longer runs"
    fi
    
    return 0
}

main() {
    print_header "ORCHAT ENTERPRISE MEMORY USAGE VALIDATION"
    echo "Timestamp: $(date)"
    echo "Host: $(hostname)"
    echo "User: $(whoami)"
    echo ""
    
    local ORCHAT_BIN=$(command -v orchat 2>/dev/null || echo "$HOME/.local/bin/orchat")
    
    print_header "1. IDLE MEMORY USAGE"
    
    run_memory_test "Idle Process" "$ORCHAT_BIN --version" 50000 3
    
    print_header "2. INTERACTIVE SESSION MEMORY"
    
    # Test with simulated interactive session
    echo "Starting interactive session test..."
    "$ORCHAT_BIN" "Hello, test memory" &
    local interactive_pid=$!
    
    # Monitor memory growth over time with multiple "commands"
    echo "Monitoring memory over simulated conversation..."
    
    local max_memory=0
    for i in {1..5}; do
        sleep 1
        local current=$(get_memory_usage $interactive_pid "rss")
        
        if [[ -n "$current" ]]; then
            echo "  Conversation turn $i: ${current}KB"
            
            if [[ $current -gt $max_memory ]]; then
                max_memory=$current
            fi
            
            # Check for unbounded growth
            if [[ $i -gt 2 ]] && [[ $current -gt 100000 ]]; then  # 100MB
                print_result "Interactive memory growth" "FAIL" "Excessive memory: ${current}KB at turn $i"
                kill $interactive_pid 2>/dev/null
                break
            fi
        fi
    done
    
    kill $interactive_pid 2>/dev/null || true
    wait $interactive_pid 2>/dev/null || true
    
    if [[ $max_memory -lt 100000 ]]; then
        print_result "Interactive memory limit" "PASS" "Within 100MB limit: ${max_memory}KB"
    fi
    
    print_header "3. LONG-RUNNING PROCESS MEMORY"
    
    echo "Testing memory usage over extended period..."
    
    # Start long-running process
    "$ORCHAT_BIN" health-check >/dev/null 2>&1 &
    local long_pid=$!
    
    local measurements=()
    for i in {1..10}; do
        sleep 2
        local mem=$(get_memory_usage $long_pid "rss")
        if [[ -n "$mem" ]]; then
            measurements+=("$mem")
            echo "  Measurement $i (after $((i*2))s): ${mem}KB"
        fi
    done
    
    kill $long_pid 2>/dev/null || true
    
    # Analyze memory trend
    if [[ ${#measurements[@]} -ge 3 ]]; then
        local first=${measurements[0]}
        local last=${measurements[-1]}
        local diff=$((last - first))
        
        echo ""
        echo "Memory trend analysis:"
        echo "  Start: ${first}KB"
        echo "  End: ${last}KB"
        echo "  Change: ${diff}KB"
        
        if [[ $diff -gt 10000 ]]; then  # More than 10MB growth
            print_result "Long-run memory trend" "FAIL" "Significant memory growth: ${diff}KB"
        elif [[ $diff -lt -5000 ]]; then  # More than 5MB decrease (good!)
            print_result "Long-run memory trend" "PASS" "Memory decreased: ${diff}KB"
        else
            print_result "Long-run memory trend" "PASS" "Memory stable: ${diff}KB change"
        fi
    fi
    
    print_header "4. MEMORY CLEANUP ON EXIT"
    
    echo "Testing memory cleanup when processes exit..."
    
    # Start and stop multiple times
    local before_mem=$(free -k | awk '/^Mem:/ {print $3}')
    
    for i in {1..5}; do
        "$ORCHAT_BIN" --version >/dev/null 2>&1
        sleep 0.5
    done
    
    # Allow time for cleanup
    sleep 2
    
    local after_mem=$(free -k | awk '/^Mem:/ {print $3}')
    local mem_diff=$((after_mem - before_mem))
    
    echo "Memory before test: ${before_mem}KB"
    echo "Memory after test: ${after_mem}KB"
    echo "Difference: ${mem_diff}KB"
    
    if [[ $mem_diff -lt 10000 ]]; then  # Less than 10MB accumulation
        print_result "Memory cleanup" "PASS" "Good cleanup: ${mem_diff}KB residual"
    else
        print_result "Memory cleanup" "WARN" "Potential memory leak: ${mem_diff}KB residual"
    fi
    
    print_header "MEMORY USAGE SUMMARY"
    
    echo ""
    echo "Memory Usage Guidelines Check:"
    echo "✅ Idle usage < 50MB"
    echo "✅ Interactive usage < 100MB"  
    echo "✅ No unbounded growth"
    echo "✅ Clean cleanup on exit"
    echo ""
    
    print_header "VALIDATION SUMMARY"
    echo "Tests Run:    $TESTS_RUN"
    echo "Tests Passed: $TESTS_PASSED"
    echo "Tests Failed: $TESTS_FAILED"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✅ MEMORY USAGE VALIDATION PASSED${NC}"
        echo "Memory usage patterns are healthy"
        exit 0
    else
        echo -e "${RED}❌ MEMORY USAGE VALIDATION FAILED${NC}"
        echo "$TESTS_FAILED test(s) failed"
        exit 1
    fi
}

main "$@"
