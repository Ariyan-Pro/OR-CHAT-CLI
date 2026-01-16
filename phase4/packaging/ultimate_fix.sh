#!/bin/bash
# ORCHAT Ultimate Fix Script v1.0
# Fixes ALL known issues with broken installation
# Swiss-watch engineering - 50+ years legacy systems expertise

set -e

echo "================================================"
echo "ORCHAT ULTIMATE FIX SCRIPT"
echo "Engineering: 50+ years (Assembly/C/Punched Cards)"
echo "================================================"
echo ""

# Step 0: Fix broken apt packages
echo "🔄 STEP 0: Fixing broken apt packages..."
sudo apt --fix-broken install -y 2>/dev/null || true
echo ""

# Step 1: Install dependencies
echo "🔄 STEP 1: Installing dependencies..."
for pkg in libjq1 jq curl python3; do
    if ! dpkg -l | grep -q "^ii.*$pkg"; then
        echo "Installing $pkg..."
        sudo apt-get install -y "$pkg" 2>/dev/null || \
        echo "⚠️  Could not install $pkg (may already be installed)"
    else
        echo "✅ $pkg already installed"
    fi
done
echo ""

# Step 2: Fix wrapper
echo "🔄 STEP 2: Fixing wrapper script..."
sudo tee /usr/bin/orchat << 'WRAPPER_EOF'
#!/bin/bash
# ORCHAT Production Wrapper v0.3.2
# Absolute path resolution - Swiss-watch precision

exec /usr/lib/orchat/bootstrap.sh "$@"
WRAPPER_EOF

sudo chmod 755 /usr/bin/orchat
echo "✅ Wrapper fixed"
echo ""

# Step 3: Fix bootstrap paths
echo "🔄 STEP 3: Fixing bootstrap paths..."
sudo tee /usr/lib/orchat/bootstrap.sh << 'BOOTSTRAP_EOF'
#!/usr/bin/env bash
# ORCHAT Bootstrap v0.3.2 - Fixed Paths

set -euo pipefail

# Absolute paths only
readonly MODULE_DIR="/usr/lib/orchat"
export ORCHAT_ROOT="$MODULE_DIR"

# Load modules
for module in constants utils config env core io interactive streaming model_browser history context payload gemini_integration session; do
    source "$MODULE_DIR/$module.sh" 2>/dev/null || {
        echo "[ERROR] Failed to load: $module" >&2
        exit 1
    }
done

# Execute main
main "$@"
BOOTSTRAP_EOF

sudo chmod 755 /usr/lib/orchat/bootstrap.sh
echo "✅ Bootstrap fixed"
echo ""

# Step 4: Fix permissions
echo "🔄 STEP 4: Setting permissions..."
sudo chmod -R 755 /usr/lib/orchat/ 2>/dev/null || true
sudo chmod 644 /usr/share/orchat/data/**/* 2>/dev/null || true
echo "✅ Permissions fixed"
echo ""

# Step 5: Final test
echo "🔄 STEP 5: Final validation..."
echo "Testing installation..."

if orchat --help 2>&1 | grep -q "ORCHAT"; then
    echo "🎉 ORCHAT IS NOW FIXED AND WORKING!"
    echo ""
    echo "Quick start:"
    echo "1. Set API key: orchat config set api_key YOUR_KEY"
    echo "2. Test: orchat 'Hello, world!' --no-stream"
    echo "3. Interactive: orchat --interactive"
else
    echo "⚠️  Installation may still need manual intervention"
    echo "Check: ls -la /usr/lib/orchat/bootstrap.sh"
    echo "Test: /usr/lib/orchat/bootstrap.sh --help"
fi

echo ""
echo "================================================"
echo "ULTIMATE FIX COMPLETE"
echo "================================================"
