#!/bin/bash
set -e

VERSION="1.0.4"
echo "Building ORCHAT Debian package v$VERSION..."

Create temp directory
TEMP_DIR=$(mktemp -d)
echo "Temp dir: $TEMP_DIR"

Create package structure
mkdir -p $TEMP_DIR/pkg/DEBIAN
mkdir -p $TEMP_DIR/pkg/usr/local/bin
mkdir -p $TEMP_DIR/pkg/usr/local/share/orchat

Copy files
echo "Copying files..."
cp bin/orchat $TEMP_DIR/pkg/usr/local/bin/
chmod +x $TEMP_DIR/pkg/usr/local/bin/orchat

cp -r src $TEMP_DIR/pkg/usr/local/share/orchat/

Create control file
cat > $TEMP_DIR/pkg/DEBIAN/control << 'CONTROL'
Package: orchat
Version: $VERSION
Architecture: all
Maintainer: ORCHAT Engineering engineering@orchat.ai
Description: ORCHAT Enterprise CLI - Swiss Watch Precision
Swiss Watch precision CLI with 50+ years engineering standards.
Section: utils
Priority: optional
Depends: curl, jq, python3
Recommends: python3-pip
CONTROL

Build package
echo "Building package..."
dpkg-deb --build $TEMP_DIR/pkg

Move to current directory
mv $TEMP_DIR/pkg.deb ./orchat_${VERSION}_all.deb

Cleanup
rm -rf $TEMP_DIR

echo "✅ Package built: orchat_${VERSION}all.deb"
ls -lh orchat${VERSION}_all.deb
