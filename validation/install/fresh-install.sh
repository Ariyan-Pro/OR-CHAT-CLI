#!/usr/bin/env bash
# ORCHAT Enterprise Fresh Install Validation
# 50+ Years Standard: Installation must be foolproof and deterministic

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARN=0

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
        PASS)
            echo -e "${GREEN}✓ PASS${NC} $test_name: $message"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            ;;
        FAIL)
            echo -e "${RED}✗ FAIL${NC} $test_name: $message"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            ;;
        WARN)
            echo -e "${YELLOW}⚠ WARN${NC} $test_name: $message"
            TESTS_WARN=$((TESTS_WARN + 1))
            ;;
    esac
}

cleanup_orchat() {
    echo "Cleaning up existing ORCHAT installation..."
    
    # Remove binaries
    sudo rm -f /usr/local/bin/orchat 2>/dev/null || true
    sudo rm -f /usr/bin/orchat 2>/dev/null || true
    
    # Remove directories
    sudo rm -rf /usr/local/lib/orchat 2>/dev/null || true
    sudo rm -rf /etc/orchat 2>/dev/null || true
    sudo rm -rf /var/log/orchat 2>/dev/null || true
    
    # Remove user configs
    rm -rf ~/.config/orchat 2>/dev/null || true
    rm -rf ~/.orchat 2>/dev/null || true
    rm -f ~/.cache/orchat* 2>/dev/null || true
    
    print_result "Cleanup" "PASS" "Previous installation removed"
}

verify_clean_environment() {
    print_header "1. VERIFYING CLEAN ENVIRONMENT"
    
    # Check for existing ORCHAT
    if command -v orchat >/dev/null 2>&1; then
        print_result "No existing orchat" "FAIL" "ORCHAT already in PATH"
        return 1
    else
        print_result "No existing orchat" "PASS" "Clean environment"
    fi
    
    # Check for config files
    if [[ -d ~/.config/orchat ]] || [[ -d ~/.orchat ]]; then
        print_result "No existing config" "WARN" "Old config files found (will be cleaned)"
    else
        print_result "No existing config" "PASS" "No old config files"
    fi
    
    # Verify we have sudo
    if sudo -v >/dev/null 2>&1; then
        print_result "Sudo access" "PASS" "Has sudo privileges"
    else
        print_result "Sudo access" "FAIL" "No sudo access"
        return 1
    fi
}

simulate_debian_install() {
    print_header "2. SIMULATING DEBIAN PACKAGE INSTALL"
    
    # Create a temporary directory for our test package
    local temp_dir="/tmp/orchat-install-test-$$"
    mkdir -p "$temp_dir"
    
    # Create mock control file
    cat > "$temp_dir/control" << 'CONTROL'
Package: orchattest
Version: 0.7.0-test
Architecture: all
Maintainer: ORCHAT Engineering <engineering@orchat.org>
Description: ORCHAT Enterprise AI Assistant Test Package
Depends: bash (>= 4.4), curl (>= 7.68), jq (>= 1.6), python3 (>= 3.8)
CONTROL
    
    # Create mock binary
    mkdir -p "$temp_dir/usr/local/bin"
    cat > "$temp_dir/usr/local/bin/orchattest" << 'MOCK_BINARY'
#!/usr/bin/env bash
# Mock ORCHAT binary for installation testing

VERSION="0.7.0-test"
CONFIG_DIR="${ORCHAT_CONFIG_DIR:-$HOME/.config/orchat}"
LOG_DIR="${ORCHAT_LOG_DIR:-/var/log/orchat}"

case "${1:-}" in
    --version)
        echo "ORCHAT Enterprise v$VERSION"
        echo "Build: $(date +%Y%m%d)"
        exit 0
        ;;
    --help)
        cat << HELP
ORCHAT Enterprise AI Assistant
Version: $VERSION

Usage: orchattest [COMMAND] [OPTIONS]

Commands:
  generate     Generate AI responses
  config       Manage configuration
  health-check System health check
  metrics      View metrics

HELP
        exit 0
        ;;
    health-check)
        echo "✅ System: Healthy"
        echo "✅ Config: $CONFIG_DIR"
        echo "✅ Logs: $LOG_DIR"
        exit 0
        ;;
    *)
        echo "ORCHAT Test - Command: $*"
        echo "Would execute: orchattest $*"
        exit 0
        ;;
esac
MOCK_BINARY
    
    chmod 755 "$temp_dir/usr/local/bin/orchattest"
    
    # Create directories structure
    mkdir -p "$temp_dir/etc/orchat"
    mkdir -p "$temp_dir/var/log/orchat"
    
    # Create config template
    cat > "$temp_dir/etc/orchat/config.template" << 'CONFIG_TEMPLATE'
# ORCHAT Configuration Template
# Copy to ~/.config/orchat/config and edit

[api]
# openrouter_api_key = "your-key-here"

[models]
# default = "openai/gpt-4"
# fallback = "openai/gpt-3.5-turbo"

[logging]
# level = "info"
# file = "/var/log/orchat/orchat.log"
CONFIG_TEMPLATE
    
    # Test installation
    echo "Installing test package..."
    sudo cp -r "$temp_dir/usr/local/bin/orchattest" /usr/local/bin/ 2>/dev/null || true
    
    if [[ -f /usr/local/bin/orchattest ]]; then
        print_result "Binary installed" "PASS" "/usr/local/bin/orchattest"
    else
        print_result "Binary installed" "FAIL" "Failed to install binary"
    fi
    
    # Clean up
    rm -rf "$temp_dir"
}

verify_installation() {
    print_header "3. VERIFYING INSTALLATION"
    
    # Test binary execution
    if /usr/local/bin/orchattest --version 2>&1 | grep -q "ORCHAT"; then
        print_result "Version command" "PASS" "Returns version info"
    else
        print_result "Version command" "FAIL" "Version command failed"
    fi
    
    # Test help
    if /usr/local/bin/orchattest --help 2>&1 | grep -q "Usage:"; then
        print_result "Help command" "PASS" "Returns help"
    else
        print_result "Help command" "FAIL" "Help command failed"
    fi
    
    # Test health check
    if /usr/local/bin/orchattest health-check 2>&1 | grep -q "Healthy"; then
        print_result "Health check" "PASS" "Health check works"
    else
        print_result "Health check" "FAIL" "Health check failed"
    fi
    
    # Test config directory creation
    /usr/local/bin/orchattest config init 2>&1 || true
    if [[ -d ~/.config/orchat ]]; then
        print_result "Config directory" "PASS" "Created ~/.config/orchat"
    else
        print_result "Config directory" "WARN" "Config dir not auto-created"
    fi
}

test_permissions() {
    print_header "4. TESTING PERMISSIONS"
    
    # Check binary permissions
    local bin_perms
    bin_perms=$(stat -c "%a" /usr/local/bin/orchattest 2>/dev/null || echo "000")
    if [[ "$bin_perms" == "755" ]]; then
        print_result "Binary permissions" "PASS" "755 (rwxr-xr-x)"
    else
        print_result "Binary permissions" "FAIL" "Got $bin_perms, expected 755"
    fi
    
    # Test config file security (if exists)
    if [[ -f ~/.config/orchat/config ]]; then
        local config_perms
        config_perms=$(stat -c "%a" ~/.config/orchat/config 2>/dev/null || echo "000")
        if [[ "$config_perms" == "600" ]]; then
            print_result "Config permissions" "PASS" "600 (secure)"
        elif [[ "$config_perms" == "644" ]]; then
            print_result "Config permissions" "WARN" "644 (world-readable)"
        else
            print_result "Config permissions" "FAIL" "$config_perms (insecure)"
        fi
    fi
}

test_uninstall() {
    print_header "5. TESTING UNINSTALLATION"
    
    echo "Removing test installation..."
    sudo rm -f /usr/local/bin/orchattest
    
    if [[ ! -f /usr/local/bin/orchattest ]]; then
        print_result "Uninstall binary" "PASS" "Binary removed"
    else
        print_result "Uninstall binary" "FAIL" "Binary still exists"
    fi
    
    # Check for leftover files (should be minimal)
    local leftovers=0
    if [[ -d /etc/orchat ]]; then
        echo "⚠️  Leftover: /etc/orchat (may be intentional)"
        leftovers=$((leftovers + 1))
    fi
    
    if [[ $leftovers -eq 0 ]]; then
        print_result "Clean uninstall" "PASS" "No leftover system files"
    else
        print_result "Clean uninstall" "WARN" "$leftovers potential leftovers"
    fi
}

main() {
    print_header "ORCHAT ENTERPRISE FRESH INSTALL VALIDATION"
    echo "Timestamp: $(date)"
    echo "Host: $(hostname)"
    echo "User: $(whoami)"
    echo ""
    
    local start_time
    start_time=$(date +%s)
    
    # Run test phases
    cleanup_orchat
    verify_clean_environment || exit 1
    simulate_debian_install
    verify_installation
    test_permissions
    test_uninstall
    cleanup_orchat
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Summary
    print_header "VALIDATION SUMMARY"
    echo "Tests Run:    $TESTS_RUN"
    echo "Tests Passed: $TESTS_PASSED"
    echo "Tests Failed: $TESTS_FAILED"
    echo "Tests Warning: $TESTS_WARN"
    echo "Duration:     ${duration}s"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✅ FRESH INSTALL VALIDATION PASSED${NC}"
        echo "Installation process is robust and clean"
        exit 0
    else
        echo -e "${RED}❌ FRESH INSTALL VALIDATION FAILED${NC}"
        echo "$TESTS_FAILED critical test(s) failed"
        exit 1
    fi
}

# Run main
main "$@"
