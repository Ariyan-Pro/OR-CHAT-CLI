#!/bin/bash
# ORCHAT Debian Package Builder
# Creates .deb package for Debian/Ubuntu

set -euo pipefail

# Configuration
VERSION="0.8.0"
ARCH="all"
MAINTAINER="ORCHAT Engineering <engineering@orchat.ai>"
DESCRIPTION="ORCHAT Enterprise AI Assistant
 Command-line AI assistant with enterprise features,
 workspace awareness, and production observability."

echo "Building ORCHAT Debian package v$VERSION..."

# Create package structure
echo "Creating package structure..."
rm -rf /tmp/orchat-pkg
mkdir -p /tmp/orchat-pkg/DEBIAN
mkdir -p /tmp/orchat-pkg/usr/lib/orchat
mkdir -p /tmp/orchat-pkg/usr/bin
mkdir -p /tmp/orchat-pkg/usr/share/doc/orchat
mkdir -p /tmp/orchat-pkg/usr/share/man/man1

# Copy source files
echo "Copying source files..."
cp -r src/* /tmp/orchat-pkg/usr/lib/orchat/
cp bin/orchat /tmp/orchat-pkg/usr/bin/
cp docs/* /tmp/orchat-pkg/usr/share/doc/orchat/ 2>/dev/null || true

# Create control file
echo "Creating control file..."
cat > /tmp/orchat-pkg/DEBIAN/control << "CONTROL"
Package: orchat
Version: $VERSION
Architecture: $ARCH
Maintainer: $MAINTAINER
Description: $DESCRIPTION
Depends: bash, curl, jq, python3
Priority: optional
Section: utils
Homepage: https://orchat.ai
CONROL

# Create postinst script
echo "Creating installation scripts..."
cat > /tmp/orchat-pkg/DEBIAN/postinst << POSTINST
#!/bin/bash
# Post-installation script
set -e

echo "ORCHAT v$VERSION installed successfully!"
echo ""
echo "To get started:"
echo "1. Set your API key:"
echo "   export OPENROUTER_API_KEY='your-key-here'"
echo "   or add to ~/.config/orchat/config"
echo "2. Test installation:"
echo "   orchat --version"
echo "3. Run validation:"
echo "   cd /usr/share/doc/orchat && ./validation/run-all.sh"
echo ""
POSTINST
chmod +x /tmp/orchat-pkg/DEBIAN/postinst

# Build package
echo "Building package..."
dpkg-deb --build /tmp/orchat-pkg orchat_${VERSION}_${ARCH}.deb

echo "✅ Package built: orchat_${VERSION}_${ARCH}.deb"
echo ""
echo "To install: sudo dpkg -i orchat_${VERSION}_${ARCH}.deb"
CONTROL
