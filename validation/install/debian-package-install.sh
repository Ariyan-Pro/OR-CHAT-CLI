#!/bin/bash
# Debian Package Installation Test
# Validates that the .deb package installs correctly

set -euo pipefail

echo "=== Debian Package Installation Test ==="
echo ""

# Check if we're on a Debian-based system
if ! command -v dpkg >/dev/null 2>&1; then
    echo "❌ Not a Debian-based system. Skipping."
    exit 0
fi

# Build the package
echo "Building Debian package..."
cd ../../
./build-debian.sh || {
    echo "❌ Failed to build Debian package"
    exit 1
}

# Install the package
echo "Installing package..."
sudo dpkg -i orchat_*.deb || {
    echo "❌ Package installation failed"
    exit 1
}

# Verify installation
echo "Verifying installation..."
if ! command -v orchat >/dev/null 2>&1; then
    echo "❌ orchat command not found after installation"
    exit 1
fi

# Test basic functionality
echo "Testing basic functionality..."
orchat --version >/dev/null 2>&1 || {
    echo "❌ orchat --version failed"
    exit 1
}

echo "✅ Debian package installation test PASSED"
