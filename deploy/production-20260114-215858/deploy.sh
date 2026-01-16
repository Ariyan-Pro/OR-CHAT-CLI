#!/usr/bin/env bash
# ORCHAT Enterprise Deployment Script
# 50+ years: Deployment should be one command away from production

set -euo pipefail

# Configuration
INSTALL_PREFIX="/usr/local"
CONFIG_DIR="/etc/orchat"
LOG_DIR="/var/log/orchat"
VERSION="0.7.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ ${1}${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ ${1}${NC}"; }
print_error() { echo -e "${RED}✗ ${1}${NC}"; }
print_step() { echo -e "\n${YELLOW}==> ${1}${NC}"; }

deploy_check_prerequisites() {
    print_step "Checking prerequisites"
    
    for cmd in bash curl jq python3; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            print_error "Missing: $cmd"
            return 1
        fi
    done
    
    print_success "All prerequisites met"
}

deploy_create_directories() {
    print_step "Creating directories"
    
    for dir in "$CONFIG_DIR" "$LOG_DIR"; do
        sudo mkdir -p "$dir"
        sudo chmod 755 "$dir"
        print_success "Created: $dir"
    done
}

deploy_install_binaries() {
    print_step "Installing binaries"
    
    # Install from current directory
    sudo cp -f ./bin/orchat "$INSTALL_PREFIX/bin/orchat"
    sudo chmod 755 "$INSTALL_PREFIX/bin/orchat"
    
    sudo cp -rf ./src/ "$INSTALL_PREFIX/lib/orchat/"
    sudo find "$INSTALL_PREFIX/lib/orchat/" -name "*.sh" -exec chmod 755 {} \;
    
    print_success "Binaries installed"
}

deploy_setup_systemd() {
    print_step "Setting up systemd service"
    
    if ! command -v systemctl >/dev/null 2>&1; then
        print_warning "systemd not found, skipping service setup"
        return
    fi
    
    sudo tee /etc/systemd/system/orchat.service > /dev/null << SYSTEMD
[Unit]
Description=ORCHAT Enterprise AI Assistant
After=network.target

[Service]
Type=simple
User=$(id -un)
Environment="ORCHAT_CONFIG_DIR=$CONFIG_DIR"
Environment="ORCHAT_LOG_DIR=$LOG_DIR"
ExecStart=$INSTALL_PREFIX/bin/orchat daemon
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SYSTEMD
    
    sudo systemctl daemon-reload
    sudo systemctl enable orchat.service
    
    print_success "Systemd service configured"
}

deploy_post_installation() {
    print_step "Post-installation"
    
    # Create symlink
    sudo ln -sf "$INSTALL_PREFIX/bin/orchat" /usr/bin/orchat 2>/dev/null || true
    
    # Initialize metrics
    if command -v "$INSTALL_PREFIX/bin/orchat" >/dev/null 2>&1; then
        "$INSTALL_PREFIX/bin/orchat" metrics-init 2>/dev/null || true
    fi
    
    print_success "ORCHAT Enterprise $VERSION deployed successfully!"
    echo ""
    echo "Quick start:"
    echo "  orchat --help                         # Show all commands"
    echo "  orchat 'Hello, AI!'                   # Chat mode"
    echo "  orchat workspace status              # Workspace intelligence"
    echo "  orchat enterprise                    # Enterprise features"
    echo "  orchat health-check                  # System health"
    echo ""
    echo "To start as service:"
    echo "  sudo systemctl start orchat"
    echo ""
    echo "Configuration: $CONFIG_DIR"
    echo "Logs: $LOG_DIR"
}

main() {
    echo "=== ORCHAT ENTERPRISE DEPLOYMENT ==="
    echo "Version: $VERSION"
    echo ""
    
    deploy_check_prerequisites
    deploy_create_directories
    deploy_install_binaries
    deploy_setup_systemd
    deploy_post_installation
    
    echo ""
    print_success "Deployment complete! 🚀"
}

main "$@"
