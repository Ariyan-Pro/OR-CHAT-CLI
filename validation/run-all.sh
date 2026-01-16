#!/usr/bin/env bash
# ORCHAT Enterprise - Complete Validation Suite
# 50+ Years Standard: Comprehensive, automated validation

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test suites and their dependencies
declare -A TEST_SUITES=(
    ["install"]="Requires: sudo access, clean environment"
    ["runtime"]="Requires: ORCHAT installed, network access"
    ["performance"]="Requires: ORCHAT installed, stable system"
    ["observability"]="Requires: ORCHAT enterprise features"
)

# Results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0
START_TIME=$(date +%s)

print_header() {
    echo -e "\n${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}\n"
}

print_stage() {
    echo -e "\n${YELLOW}▶ $1${NC}"
}

print_result() {
    local suite="$1"
    local test="$2"
    local status="$3"
    local message="$4"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    case "$status" in
        PASS)
            echo -e "${GREEN}  ✓ PASS${NC} $suite/$test: $message"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            ;;
        FAIL)
            echo -e "${RED}  ✗ FAIL${NC} $suite/$test: $message"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            ;;
        SKIP)
            echo -e "${BLUE}  ⏭ SKIP${NC} $suite/$test: $message"
            SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
            ;;
        WARN)
            echo -e "${YELLOW}  ⚠ WARN${NC} $suite/$test: $message"
            ;;
    esac
}

check_prerequisites() {
    print_header "PREREQUISITE CHECK"
    
    local missing=0
    
    # Check for ORCHAT
    if ! command -v orchat >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠ ORCHAT not installed${NC}"
        echo "  Some tests will be skipped"
        missing=1
    else
        echo -e "${GREEN}✓ ORCHAT installed${NC}"
        echo "  Version: $(orchat --version 2>/dev/null | head -1 || echo "Unknown")"
    fi
    
    # Check for dependencies
    for dep in bash curl jq python3; do
        if command -v "$dep" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ $dep available${NC}"
        else
            echo -e "${RED}✗ $dep missing${NC}"
            missing=1
        fi
    done
    
    # Check for sudo
    if sudo -v >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Sudo available${NC}"
    else
        echo -e "${YELLOW}⚠ No sudo access${NC}"
        echo "  Installation tests will be skipped"
    fi
    
    # Check for API key
    if [[ -n "${ORCHAT_API_KEY:-}" ]] || [[ -f ~/.config/orchat/config ]]; then
        echo -e "${GREEN}✓ API key configured${NC}"
    else
        echo -e "${YELLOW}⚠ No API key configured${NC}"
        echo "  API tests will use failure modes"
    fi
    
    return $missing
}

run_install_tests() {
    print_stage "INSTALLATION TEST SUITE"
    
    local suite_dir="validation/install"
    
    for test_file in "$suite_dir"/*.sh; do
        local test_name
        test_name=$(basename "$test_file" .sh)
        
        # Skip if not executable
        if [[ ! -x "$test_file" ]]; then
            print_result "install" "$test_name" "SKIP" "Not executable"
            continue
        fi
        
        print_stage "Running: $test_name"
        
        # Run test with timeout
        if timeout 300 bash "$test_file" 2>&1; then
            print_result "install" "$test_name" "PASS" "Completed successfully"
        else
            local exit_code=$?
            if [[ $exit_code -eq 124 ]]; then
                print_result "install" "$test_name" "FAIL" "Timed out after 300s"
            else
                print_result "install" "$test_name" "FAIL" "Failed with exit code $exit_code"
            fi
        fi
    done
}

run_runtime_tests() {
    print_stage "RUNTIME TEST SUITE"
    
    local suite_dir="validation/runtime"
    
    for test_file in "$suite_dir"/*.sh; do
        local test_name
        test_name=$(basename "$test_file" .sh)
        
        if [[ ! -x "$test_file" ]]; then
            print_result "runtime" "$test_name" "SKIP" "Not executable"
            continue
        fi
        
        print_stage "Running: $test_name"
        
        if timeout 120 bash "$test_file" 2>&1; then
            print_result "runtime" "$test_name" "PASS" "Completed successfully"
        else
            local exit_code=$?
            if [[ $exit_code -eq 124 ]]; then
                print_result "runtime" "$test_name" "FAIL" "Timed out after 120s"
            else
                print_result "runtime" "$test_name" "FAIL" "Failed with exit code $exit_code"
            fi
        fi
    done
}

run_performance_tests() {
    print_stage "PERFORMANCE TEST SUITE"
    
    local suite_dir="validation/performance"
    
    for test_file in "$suite_dir"/*.sh; do
        local test_name
        test_name=$(basename "$test_file" .sh)
        
        if [[ ! -x "$test_file" ]]; then
            print_result "performance" "$test_name" "SKIP" "Not executable"
            continue
        fi
        
        print_stage "Running: $test_name"
        
        if timeout 600 bash "$test_file" 2>&1; then
            print_result "performance" "$test_name" "PASS" "Completed successfully"
        else
            local exit_code=$?
            if [[ $exit_code -eq 124 ]]; then
                print_result "performance" "$test_name" "FAIL" "Timed out after 600s"
            else
                print_result "performance" "$test_name" "FAIL" "Failed with exit code $exit_code"
            fi
        fi
    done
}

run_observability_tests() {
    print_stage "OBSERVABILITY TEST SUITE"
    
    local suite_dir="validation/observability"
    
    # Check if enterprise features are available
    if ! orchat enterprise --help 2>/dev/null | grep -q "metrics\|health"; then
        print_result "observability" "all" "SKIP" "Enterprise features not available"
        return
    fi
    
    for test_file in "$suite_dir"/*.sh; do
        local test_name
        test_name=$(basename "$test_file" .sh)
        
        if [[ ! -x "$test_file" ]]; then
            print_result "observability" "$test_name" "SKIP" "Not executable"
            continue
        fi
        
        print_stage "Running: $test_name"
        
        if timeout 300 bash "$test_file" 2>&1; then
            print_result "observability" "$test_name" "PASS" "Completed successfully"
        else
            local exit_code=$?
            if [[ $exit_code -eq 124 ]]; then
                print_result "observability" "$test_name" "FAIL" "Timed out after 300s"
            else
                print_result "observability" "$test_name" "FAIL" "Failed with exit code $exit_code"
            fi
        fi
    done
}

generate_final_report() {
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    
    print_header "ORCHAT ENTERPRISE VALIDATION REPORT"
    
    echo "Validation Completed: $(date)"
    echo "Duration: ${duration} seconds"
    echo ""
    
    echo "=== EXECUTIVE SUMMARY ==="
    echo "Total Tests:    $TOTAL_TESTS"
    echo "Tests Passed:   $PASSED_TESTS"
    echo "Tests Failed:   $FAILED_TESTS"
    echo "Tests Skipped:  $SKIPPED_TESTS"
    echo ""
    
    echo "=== SUITE BREAKDOWN ==="
    for suite in "${!TEST_SUITES[@]}"; do
        echo "  $suite: ${TEST_SUITES[$suite]}"
    done
    echo ""
    
    echo "=== RECOMMENDATIONS ==="
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}✅ ALL VALIDATION TESTS PASSED${NC}"
        echo ""
        echo "ORCHAT Enterprise v0.7.0 meets all validation criteria."
        echo "Ready for production deployment."
    else
        echo -e "${YELLOW}⚠ VALIDATION HAS FAILURES${NC}"
        echo ""
        echo "Failures detected in $FAILED_TESTS test(s)."
        echo "Review failure logs and address before production deployment."
        echo ""
        echo "Next steps:"
        echo "1. Review validation/reports/failure-log.md"
        echo "2. Fix failing tests"
        echo "3. Re-run validation"
    fi
    
    echo ""
    echo "=== DETAILED LOGS ==="
    echo "Test output logged to: validation/reports/daily-log.md"
    echo "Failures logged to:    validation/reports/failure-log.md"
    echo "Final report:          validation/reports/final-validation-report.md"
    
    # Update failure log
    if [[ $FAILED_TESTS -gt 0 ]]; then
        echo -e "\n${RED}❌ VALIDATION FAILED${NC}" >> validation/reports/failure-log.md
        echo "Date: $(date)" >> validation/reports/failure-log.md
        echo "Failed tests: $FAILED_TESTS" >> validation/reports/failure-log.md
    fi
    
    # Update final report
    cat > validation/reports/final-validation-report.md << FINAL_REPORT
# ORCHAT Enterprise Final Validation Report

## Validation Summary
- **Version Tested:** v0.7.0
- **Validation Date:** $(date)
- **Duration:** ${duration} seconds
- **Total Tests:** $TOTAL_TESTS
- **Tests Passed:** $PASSED_TESTS
- **Tests Failed:** $FAILED_TESTS
- **Tests Skipped:** $SKIPPED_TESTS

## Test Suite Results
1. **Installation Tests:** $(ls validation/install/*.sh 2>/dev/null | wc -l) tests
2. **Runtime Tests:** $(ls validation/runtime/*.sh 2>/dev/null | wc -l) tests
3. **Performance Tests:** $(ls validation/performance/*.sh 2>/dev/null | wc -l) tests
4. **Observability Tests:** $(ls validation/observability/*.sh 2>/dev/null | wc -l) tests

## Conclusion
$(
if [[ $FAILED_TESTS -eq 0 ]]; then
    echo "✅ **PASS** - All validation criteria met."
    echo "ORCHAT Enterprise v0.7.0 is ready for production deployment."
else
    echo "❌ **FAIL** - $FAILED_TESTS test(s) failed."
    echo "Address failures before production deployment."
fi
)

## Sign-off
- **Engineering Lead:** ___________________
- **Quality Assurance:** ___________________
- **Security Officer:** ___________________
- **Architecture Review:** ___________________

*Report generated by ORCHAT Enterprise Validation Suite*
FINAL_REPORT
}

main() {
    print_header "ORCHAT ENTERPRISE COMPLETE VALIDATION"
    echo "Phase 7.5 - Engineering Freeze Validation"
    echo "Starting at: $(date)"
    echo ""
    
    # Create reports directory
    mkdir -p validation/reports
    
    # Initialize logs
    echo "# ORCHAT Validation Log - $(date)" > validation/reports/daily-log.md
    echo "" >> validation/reports/daily-log.md
    
    # Check prerequisites
    check_prerequisites
    echo ""
    
    # Run test suites
    run_install_tests
    run_runtime_tests
    run_performance_tests
    run_observability_tests
    
    # Generate report
    generate_final_report
    
    # Return appropriate exit code
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "\n${GREEN}✅ VALIDATION COMPLETE - ALL TESTS PASSED${NC}"
        exit 0
    else
        echo -e "\n${RED}❌ VALIDATION COMPLETE - $FAILED_TESTS TEST(S) FAILED${NC}"
        exit 1
    fi
}

# Redirect all output to log file as well
main "$@" 2>&1 | tee -a validation/reports/daily-log.md
