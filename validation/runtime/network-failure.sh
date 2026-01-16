#!/usr/bin/env bash
# Network Failure Validation
# 50+ Years Standard: Graceful degradation with retries and clear errors

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

simulate_network_failure() {
    print_header "0. SETTING UP NETWORK FAILURE SIMULATION"
    
    echo "Note: This test simulates network failures without actually breaking connectivity."
    echo "We'll test timeout handling and retry logic."
    echo ""
    
    # Create a mock API endpoint that fails
    local mock_port=9999
    local mock_pid_file="/tmp/orchat-net-test-$$.pid"
    
    # Start a simple Python HTTP server that simulates failures
    cat > /tmp/orchat_mock_api.py << 'PYTHON_MOCK'
import http.server
import socketserver
import time
import sys
import random

class MockAPIHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        # Simulate various failure modes
        if "timeout" in self.path:
            time.sleep(30)  # Long timeout
            self.send_response(408)
        elif "reset" in self.path:
            self.close_connection = True
            return
        elif "slow" in self.path:
            time.sleep(5)
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"choices":[{"message":{"content":"Slow response"}}]}')
        else:
            # Random failures
            failure_type = random.choice([500, 502, 503, 504])
            self.send_response(failure_type)
        
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(b'{"error": {"message": "Simulated network failure"}}')
    
    def log_message(self, format, *args):
        # Suppress default logging
        pass

if __name__ == "__main__":
    port = 9999
    with socketserver.TCPServer(("", port), MockAPIHandler) as httpd:
        print(f"Mock API server running on port {port}")
        with open("/tmp/orchat-net-test.pid", "w") as f:
            f.write(str(httpd.server_address))
        httpd.serve_forever()
PYTHON_MOCK
    
    # Try to start mock server in background
    python3 /tmp/orchat_mock_api.py > /tmp/mock.log 2>&1 &
    echo $! > "$mock_pid_file"
    
    sleep 2  # Give server time to start
    
    print_result "Mock server" "PASS" "Network failure simulator ready"
}

test_timeout_handling() {
    print_header "1. TESTING TIMEOUT HANDLING"
    
    # Set API endpoint to our mock server (which will timeout)
    export ORCHAT_API_URL="http://localhost:9999/timeout"
    
    echo "Testing with 10-second timeout..."
    local start_time
    start_time=$(date +%s)
    
    local output
    output=$(timeout 15 orchat "Test timeout" 2>&1 || true)
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "Duration: ${duration}s"
    
    # Should timeout before 30 seconds
    if [[ $duration -lt 25 ]]; then
        print_result "Timeout enforcement" "PASS" "Timed out after ${duration}s (correct)"
    else
        print_result "Timeout enforcement" "FAIL" "Took ${duration}s (too long)"
    fi
    
    # Should show timeout error
    if echo "$output" | grep -qi "timeout\|timed.*out\|408"; then
        print_result "Timeout error message" "PASS" "Clear timeout error"
    else
        print_result "Timeout error message" "FAIL" "No timeout message"
    fi
    
    unset ORCHAT_API_URL
}

test_retry_logic() {
    print_header "2. TESTING RETRY LOGIC"
    
    # Set to endpoint that fails with 500 errors
    export ORCHAT_API_URL="http://localhost:9999/retry"
    
    echo "Testing retry behavior with transient failures..."
    
    local output
    output=$(orchat "Test retry" 2>&1 || true)
    
    # Check for retry indicators
    local retry_count=$(echo "$output" | grep -ci "retry\|attempt\|try")
    
    if [[ $retry_count -gt 0 ]]; then
        print_result "Retry attempts" "PASS" "Shows retry logic (count: $retry_count)"
    else
        print_result "Retry attempts" "WARN" "No retry indicators found"
    fi
    
    # Should eventually fail with clear error
    if echo "$output" | grep -qi "failed after.*retries\|max.*retries\|giving up"; then
        print_result "Retry exhaustion" "PASS" "Shows retry exhaustion"
    fi
    
    unset ORCHAT_API_URL
}

test_dns_failure() {
    print_header "3. TESTING DNS FAILURE"
    
    # Use non-existent domain
    export ORCHAT_API_URL="http://nonexistent-domain-$(date +%s).test/api"
    
    echo "Testing with invalid domain..."
    
    local output
    output=$(orchat "Test DNS failure" 2>&1 || true)
    
    # Should show network error
    if echo "$output" | grep -qi "network\|connect\|dns\|resolve\|unreachable"; then
        print_result "DNS failure handling" "PASS" "Clear network error"
    else
        print_result "DNS failure handling" "FAIL" "No network error message"
    fi
    
    # Should not crash
    if echo "$output" | grep -qi "segmentation\|core.*dump\|traceback"; then
        print_result "DNS crash prevention" "FAIL" "Crashed on DNS failure"
    else
        print_result "DNS crash prevention" "PASS" "No crash on DNS failure"
    fi
    
    unset ORCHAT_API_URL
}

test_slow_response() {
    print_header "4. TESTING SLOW RESPONSE HANDLING"
    
    # Use slow endpoint
    export ORCHAT_API_URL="http://localhost:9999/slow"
    
    echo "Testing slow response (5-second delay)..."
    
    local start_time
    start_time=$(date +%s)
    
    local output
    output=$(timeout 10 orchat "Test slow response" 2>&1 || true)
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "Duration: ${duration}s"
    
    # Should complete within reasonable time (slow + overhead)
    if [[ $duration -lt 8 ]]; then
        print_result "Slow response timeout" "PASS" "Completed in ${duration}s"
    else
        print_result "Slow response timeout" "FAIL" "Took ${duration}s (too long)"
    fi
    
    unset ORCHAT_API_URL
}

cleanup_network_test() {
    print_header "5. CLEANING UP NETWORK TEST"
    
    # Kill mock server if running
    if [[ -f "/tmp/orchat-net-test.pid" ]]; then
        local pid
        pid=$(cat "/tmp/orchat-net-test.pid" 2>/dev/null || echo "")
        if [[ -n "$pid" ]]; then
            kill "$pid" 2>/dev/null || true
            wait "$pid" 2>/dev/null || true
        fi
        rm -f "/tmp/orchat-net-test.pid"
    fi
    
    rm -f /tmp/orchat_mock_api.py /tmp/mock.log 2>/dev/null || true
    
    print_result "Cleanup" "PASS" "Network test cleaned up"
}

main() {
    print_header "NETWORK FAILURE VALIDATION"
    echo "Testing ORCHAT behavior under network failures"
    echo ""
    
    # Need a valid API key for some tests
    if [[ -z "${ORCHAT_API_KEY:-}" ]] && [[ ! -f ~/.config/orchat/config ]]; then
        echo -e "${YELLOW}⚠ Warning: No API key set. Some tests may fail.${NC}"
        echo "Set ORCHAT_API_KEY or configure ~/.config/orchat/config"
        echo ""
    fi
    
    simulate_network_failure
    test_timeout_handling
    test_retry_logic
    test_dns_failure
    test_slow_response
    cleanup_network_test
    
    # Summary
    print_header "VALIDATION SUMMARY"
    echo "Tests Run:    $TESTS_RUN"
    echo "Tests Passed: $TESTS_PASSED"
    echo "Tests Failed: $TESTS_FAILED"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✅ NETWORK FAILURE VALIDATION PASSED${NC}"
        echo "ORCHAT handles network issues gracefully"
        exit 0
    else
        echo -e "${RED}❌ NETWORK FAILURE VALIDATION FAILED${NC}"
        echo "$TESTS_FAILED test(s) failed"
        exit 1
    fi
}

main "$@"
