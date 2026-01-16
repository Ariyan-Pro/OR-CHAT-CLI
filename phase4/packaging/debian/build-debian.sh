#!/bin/bash
# Build ORCHAT Debian package - FINAL CORRECTED VERSION
# MUST BE RUN FROM: /mnt/c/Users/dell/Projects/orchat/phase4/packaging/debian

set -e

echo "🏗️  Building ORCHAT Debian package..."
echo "Working directory: $(pwd)"
echo ""

# Verify we're in the right place
if [ ! -f "control" ]; then
    echo "❌ ERROR: Not in debian packaging directory!"
    echo "Expected control file not found."
    echo "Run this script from: /mnt/c/Users/dell/Projects/orchat/phase4/packaging/debian"
    exit 1
fi

echo "✅ Verified: In correct packaging directory"
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf orchat_*.deb build 2>/dev/null || true

# Create fresh build directory
echo "📁 Creating directory structure..."
mkdir -p build/DEBIAN
mkdir -p build/usr/{bin,lib/orchat,share/doc/orchat}
mkdir -p build/etc/orchat
mkdir -p build/usr/share/orchat/data

# Copy control files
echo "📄 Copying control files..."
cp control build/DEBIAN/
cp postinst build/DEBIAN/
cp prerm build/DEBIAN/

echo "✅ Control files copied"
echo ""

# Define project root
PROJECT_ROOT="/mnt/c/Users/dell/Projects/orchat"
echo "📦 Source project: $PROJECT_ROOT"

# Verify source files exist
verify_file() {
    local file="$1"
    if [ ! -e "$file" ]; then
        echo "❌ MISSING: $file"
        return 1
    fi
    echo "✅ Found: $file"
    return 0
}

echo ""
echo "🔍 Verifying source files..."
verify_file "$PROJECT_ROOT/bin/orchat" || exit 1
verify_file "$PROJECT_ROOT/bin/orchat.robust" || exit 1
verify_file "$PROJECT_ROOT/src" || exit 1
verify_file "$PROJECT_ROOT/config/orchat.toml" || exit 1
verify_file "$PROJECT_ROOT/config/schema.json" || exit 1

echo ""
echo "✅ All source files verified"
echo ""

# Copy binaries
echo "📋 Copying binaries..."
cp "$PROJECT_ROOT/bin/orchat" build/usr/bin/
cp "$PROJECT_ROOT/bin/orchat.robust" build/usr/bin/orchat-robust

# Copy source modules
echo "📦 Copying source modules ($(ls "$PROJECT_ROOT"/src/*.sh | wc -l) files)..."
cp "$PROJECT_ROOT"/src/*.sh build/usr/lib/orchat/

# Copy configuration
echo "⚙️  Copying configuration..."
cp "$PROJECT_ROOT/config/orchat.toml" build/etc/orchat/orchat.toml.dist
cp "$PROJECT_ROOT/config/schema.json" build/usr/share/doc/orchat/

# Copy data files if they exist
if [ -d "$PROJECT_ROOT/data" ]; then
    echo "📁 Copying data files..."
    cp -r "$PROJECT_ROOT"/data/* build/usr/share/orchat/data/ 2>/dev/null || true
fi

echo ""
echo "✅ All files copied to build directory"
echo ""

# Create examples
echo "📚 Creating examples..."
mkdir -p build/usr/share/doc/orchat/examples
cat > build/usr/share/doc/orchat/examples/basic-usage.sh << 'EXAMPLES_EOF'
#!/bin/bash
# ORCHAT Usage Examples

echo "ORCHAT Debian Package Installed Successfully!"
echo ""
echo "Quick Start:"
echo "1. Set your API key:"
echo "   mkdir -p ~/.config/orchat"
echo "   echo 'your-api-key-here' > ~/.config/orchat/config"
echo "   chmod 600 ~/.config/orchat/config"
echo ""
echo "2. Test installation:"
echo "   orchat 'Hello from Debian package!' --no-stream"
echo ""
echo "3. Explore features:"
echo "   orchat --help"
echo "   orchat -i  # Interactive mode"
echo "   orchat config list"
EXAMPLES_EOF

chmod 755 build/usr/share/doc/orchat/examples/basic-usage.sh

# Calculate installed size
echo "📏 Calculating installed size..."
INSTALLED_SIZE=$(du -sk build/usr 2>/dev/null | cut -f1 || echo "10")
echo "Installed size: $INSTALLED_SIZE KB"

# Update control file with installed size
if grep -q "^Installed-Size:" build/DEBIAN/control; then
    sed -i "s/^Installed-Size:.*/Installed-Size: $INSTALLED_SIZE/" build/DEBIAN/control
else
    echo "Installed-Size: $INSTALLED_SIZE" >> build/DEBIAN/control
fi

# Set permissions
echo "🔒 Setting permissions..."
find build -type f -name "*.sh" -exec chmod 755 {} \;
find build -type d -exec chmod 755 {} \;
chmod 644 build/etc/orchat/orchat.toml.dist
chmod 644 build/usr/share/doc/orchat/schema.json

echo ""
echo "✅ Build directory prepared"
echo ""

# Build the package
echo "🚀 Building Debian package with dpkg-deb..."
dpkg-deb --build build orchat_0.3.0_all.deb

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉🎉🎉 SUCCESS! 🎉🎉🎉"
    echo ""
    echo "Package: orchat_0.3.0_all.deb"
    echo "Size: $(du -h orchat_0.3.0_all.deb | cut -f1)"
    echo ""
    
    # Verify the package
    echo "📋 Package structure:"
    if command -v dpkg >/dev/null 2>&1; then
        dpkg -c orchat_0.3.0_all.deb | head -20
    else
        echo "Using 'ar' to list contents:"
        ar t orchat_0.3.0_all.deb
    fi
    
    echo ""
    echo "📄 Package metadata:"
    dpkg -I orchat_0.3.0_all.deb 2>/dev/null || echo "(Metadata view not available)"
    
    echo ""
    echo "✅✅✅ DEBIAN PACKAGE BUILT SUCCESSFULLY! ✅✅✅"
    echo ""
    echo "📦 Installation:"
    echo "   sudo dpkg -i orchat_0.3.0_all.deb"
    echo ""
    echo "🧹 Removal:"
    echo "   sudo dpkg -r orchat"
    echo ""
    echo "🧪 Test after installation:"
    echo "   orchat 'Hello from Debian package!' --no-stream"
else
    echo ""
    echo "❌ Package build failed"
    echo ""
    echo "Debug information:"
    echo "Build directory contents:"
    find build -type f | sort
    echo ""
    echo "Control file:"
    cat build/DEBIAN/control
    echo ""
    echo "Trying verbose build..."
    dpkg-deb --verbose --build build orchat_0.3.0_all.deb 2>&1
fi
