#!/bin/bash
# Build all ORCHAT packages

set -e

echo "=== ORCHAT PACKAGE BUILDER ==="
echo ""

# Check dependencies
command -v dpkg-deb >/dev/null 2>&1 || echo "Warning: dpkg-deb not found (skipping .deb)"
command -v rpmbuild >/dev/null 2>&1 || echo "Warning: rpmbuild not found (skipping .rpm)"
command -v docker >/dev/null 2>&1 || echo "Warning: docker not found (skipping Docker)"

# Create build directory
BUILD_DIR="build-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "Building packages in: $(pwd)"
echo ""

# 1. Debian package
if command -v dpkg-deb >/dev/null 2>&1; then
    echo "Building Debian package..."
    mkdir -p debian
    cd ../debian
    ./build-debian.sh 2>&1 | tail -10
    cp orchat_*.deb "../../$BUILD_DIR/" 2>/dev/null || true
    cd "../../$BUILD_DIR"
    echo "✅ Debian package ready"
    echo ""
fi

# 2. Create source tarball for RPM
echo "Creating source tarball..."
cd /mnt/c/Users/dell/Projects/orchat
tar -czf "../phase4/packaging/$BUILD_DIR/orchat-0.3.0.tar.gz" \
    --exclude="*.deb" \
    --exclude="*.rpm" \
    --exclude="*node_modules*" \
    --exclude="*.git*" \
    --exclude="phase4" \
    .
cd "../phase4/packaging/$BUILD_DIR"

# 3. RPM package (if rpmbuild available)
if command -v rpmbuild >/dev/null 2>&1; then
    echo "Building RPM package..."
    mkdir -p rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
    cp orchat-0.3.0.tar.gz rpmbuild/SOURCES/
    cp ../rpm/orchat.spec rpmbuild/SPECS/
    
    rpmbuild -bb \
        --define "_topdir $(pwd)/rpmbuild" \
        --define "_version 0.3.0" \
        --define "_release 1" \
        rpmbuild/SPECS/orchat.spec 2>&1 | tail -20
    
    cp rpmbuild/RPMS/noarch/*.rpm . 2>/dev/null || true
    echo "✅ RPM package ready"
    echo ""
fi

# 4. Docker image
if command -v docker >/dev/null 2>&1; then
    echo "Building Docker image..."
    cd ../docker
    docker build -t orchat:0.3.0 . 2>&1 | tail -10
    echo "✅ Docker image built: orchat:0.3.0"
    echo ""
fi

# Summary
cd "/mnt/c/Users/dell/Projects/orchat/phase4/packaging/$BUILD_DIR"
echo "=== BUILD COMPLETE ==="
echo ""
echo "Generated packages:"
ls -la *.deb *.rpm 2>/dev/null || echo "No binary packages generated"
echo ""
echo "Docker image: orchat:0.3.0"
echo ""
echo "To install Debian package: sudo dpkg -i orchat_*.deb"
echo "To install RPM package: sudo rpm -i orchat-*.rpm"
echo "To run Docker: docker run -it orchat:0.3.0"
