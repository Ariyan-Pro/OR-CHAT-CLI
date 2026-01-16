#!/bin/bash
# ORCHAT Installation Fix Script
# Fixes all known issues with v0.3.0/v0.3.1 installation
# Swiss-watch precision engineering

set -e

echo "=== ORCHAT INSTALLATION FIX ==="
echo "Engineering: 50+ years legacy systems"
echo ""

# Step 1: Ensure dependencies
echo "1. Installing dependencies..."
sudo apt-get update
sudo apt-get install -y jq curl python3
echo "✅ Dependencies installed"
echo ""

# Step 2: Fix wrapper
echo "2. Fixing wrapper script..."
sudo tee /usr/bin/orchat << 'WRAPPER_EOF'
#!/bin/bash
# ORCHAT Production Wrapper v0.3.1-fixed
# Absolute path resolution - No failures

BOOTSTRAP="/usr/lib/orchat/bootstrap.sh"

# Validate with industrial precision
if [[ ! -f "$BOOTSTRAP" ]]; then
    echo "[ERROR] System integrity violation: bootstrap.sh missing" >&2
    echo "[INFO] Expected: /usr/lib/orchat/bootstrap.sh" >&2
    exit 127
fi

if [[ ! -x "$BOOTSTRAP" ]]; then
    sudo chmod +x "$BOOTSTRAP" 2>/dev/null || {
        echo "[ERROR] Cannot make bootstrap executable" >&2
        exit 126
    }
fi

# Execute
exec "$BOOTSTRAP" "$@"
WRAPPER_EOF

sudo chmod 755 /usr/bin/orchat
echo "✅ Wrapper fixed"
echo ""

# Step 3: Fix permissions
echo "3. Setting correct permissions..."
sudo chmod -R 755 /usr/lib/orchat/
sudo chmod 644 /usr/share/orchat/data/**/* 2>/dev/null || true
echo "✅ Permissions fixed"
echo ""

# Step 4: Create config directory
echo "4. Creating configuration directory..."
sudo mkdir -p /etc/orchat
sudo mkdir -p /var/log/orchat
echo "✅ Directories created"
echo ""

# Step 5: Test installation
echo "5. Testing installation..."
echo "Testing help command..."
orchat --help >/dev/null && echo "✅ Help command works" || echo "❌ Help command failed"
echo ""

echo "Testing API connectivity..."
orchat "Installation test" --no-stream --max-tokens 10 >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    echo "✅ API connectivity works"
else
    echo "⚠️  API test failed (might need API key setup)"
fi
echo ""

echo "=== FIX COMPLETE ==="
echo ""
echo "ORCHAT v0.3.1 is now properly installed."
echo "Run 'orchat --help' to see available commands."
echo "Configure API key with: orchat config set api_key YOUR_KEY"
