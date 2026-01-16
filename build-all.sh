#!/usr/bin/env bash
#
# BUILD-ALL: Complete packaging for all platforms
# Phase 4.1: Packaging systems implementation
#

set -euo pipefail

# Configuration
VERSION="1.0.0"
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
BUILD_DIR="./build"
DIST_DIR="./dist"
PACKAGE_NAME="orchat"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_header() {
    echo -e "\n${GREEN}=== $1 ===${NC}"
}

print_step() {
    echo -e "${YELLOW}▶ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Clean build directories
clean_build() {
    print_header "CLEANING BUILD DIRECTORIES"
    
    for dir in "$BUILD_DIR" "$DIST_DIR"; do
        if [[ -d "$dir" ]]; then
            rm -rf "$dir"
            print_success "Removed: $dir"
        fi
        mkdir -p "$dir"
        print_success "Created: $dir"
    done
}

# Build Debian package (.deb)
build_debian() {
    print_header "BUILDING DEBIAN PACKAGE (.deb)"
    
    local deb_dir="$BUILD_DIR/debian/$PACKAGE_NAME-$VERSION"
    mkdir -p "$deb_dir/DEBIAN"
    mkdir -p "$deb_dir/usr/local/bin"
    mkdir -p "$deb_dir/usr/local/share/orchat"
    mkdir -p "$deb_dir/etc/orchat"
    
    # Copy files
    cp -r bin/ "$deb_dir/usr/local/bin/"
    cp -r config/ "$deb_dir/etc/orchat/"
    cp -r src/ "$deb_dir/usr/local/share/orchat/"
    
    # Create control file
    cat > "$deb_dir/DEBIAN/control" << CONTROL
Package: $PACKAGE_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: all
Maintainer: ORCHAT Team <team@orchat.ai>
Description: Intelligent CLI chat interface with multi-turn conversations
 ORCHAT is a command-line chat interface with advanced features:
  * Multi-turn conversation memory
  * Configurable AI models
  * Deterministic mode for testing
  * Comprehensive diagnostics
Homepage: https://github.com/orchat/orchat
Depends: bash (>= 4.0), curl, jq
Recommends: python3
Control
    
    # Create postinst script
    cat > "$deb_dir/DEBIAN/postinst" << POSTINST
#!/bin/bash
# Post-installation script for ORCHAT

echo "ORCHAT $VERSION installed successfully!"
echo ""
echo "To get started:"
echo "  1. Configure API key:"
echo "     cp /etc/orchat/orchat.toml.example ~/.config/orchat.toml"
echo "     # Edit with your API key"
echo ""
echo "  2. Run ORCHAT:"
echo "     orchat 'Hello, world!'"
echo ""
echo "  3. Check system health:"
echo "     orchat doctor"
POSTINST
    chmod +x "$deb_dir/DEBIAN/postinst"
    
    # Build package
    dpkg-deb --build "$deb_dir" "$DIST_DIR/${PACKAGE_NAME}_${VERSION}_all.deb" 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        print_success "Debian package built: $DIST_DIR/${PACKAGE_NAME}_${VERSION}_all.deb"
    else
        print_error "Failed to build Debian package"
        return 1
    fi
}

# Build RPM package (.rpm)
build_rpm() {
    print_header "BUILDING RPM PACKAGE (.rpm)"
    
    local rpm_dir="$BUILD_DIR/rpm"
    mkdir -p "$rpm_dir/SPECS"
    mkdir -p "$rpm_dir/BUILD"
    mkdir -p "$rpm_dir/RPMS"
    mkdir -p "$rpm_dir/SOURCES"
    
    # Create spec file
    cat > "$rpm_dir/SPECS/$PACKAGE_NAME.spec" << SPEC
Name: $PACKAGE_NAME
Version: $VERSION
Release: 1%{?dist}
Summary: Intelligent CLI chat interface
License: MIT
URL: https://github.com/orchat/orchat
Source0: $PACKAGE_NAME-$VERSION.tar.gz
BuildArch: noarch
Requires: bash, curl, jq
Recommends: python3

%description
ORCHAT is a command-line chat interface with advanced features:
* Multi-turn conversation memory
* Configurable AI models  
* Deterministic mode for testing
* Comprehensive diagnostics

%prep
%setup -q

%build
# Nothing to build (bash script)

%install
mkdir -p %{buildroot}/usr/local/bin
mkdir -p %{buildroot}/etc/orchat
mkdir -p %{buildroot}/usr/local/share/orchat

cp -r bin/* %{buildroot}/usr/local/bin/
cp -r config/* %{buildroot}/etc/orchat/
cp -r src/* %{buildroot}/usr/local/share/orchat/

%files
/usr/local/bin/orchat
/etc/orchat/orchat.toml.example
/usr/local/share/orchat/*

%post
echo "ORCHAT $VERSION installed successfully!"
echo ""
echo "To get started:"
echo "  1. Configure API key:"
echo "     cp /etc/orchat/orchat.toml.example ~/.config/orchat.toml"
echo "     # Edit with your API key"
echo ""
echo "  2. Run ORCHAT:"
echo "     orchat 'Hello, world!'"

%changelog
* $(date '+%a %b %d %Y') ORCHAT Team <team@orchat.ai> - $VERSION-1
- Initial RPM package
SPEC
    
    # Create tarball source
    tar czf "$rpm_dir/SOURCES/$PACKAGE_NAME-$VERSION.tar.gz" \
        --transform "s,^,$PACKAGE_NAME-$VERSION/," \
        bin/ config/ src/ LICENSE README.md
    
    # Build RPM (simulate if rpmbuild not available)
    if command -v rpmbuild &>/dev/null; then
        rpmbuild --define "_topdir $(pwd)/$rpm_dir" -bb "$rpm_dir/SPECS/$PACKAGE_NAME.spec"
        cp "$rpm_dir/RPMS/noarch/"*.rpm "$DIST_DIR/"
        print_success "RPM package built"
    else
        print_warning "rpmbuild not available, creating mock RPM package"
        touch "$DIST_DIR/${PACKAGE_NAME}-${VERSION}-1.noarch.rpm.mock"
        print_success "Mock RPM package created (install rpmbuild for real package)"
    fi
}

# Build Docker container
build_docker() {
    print_header "BUILDING DOCKER CONTAINER"
    
    local docker_dir="$BUILD_DIR/docker"
    mkdir -p "$docker_dir"
    
    # Create Dockerfile
    cat > "$docker_dir/Dockerfile" << DOCKERFILE
FROM alpine:latest

RUN apk add --no-cache \
    bash \
    curl \
    jq \
    python3

WORKDIR /app

COPY bin/ /usr/local/bin/
COPY config/ /etc/orchat/
COPY src/ /usr/local/share/orchat/

# Create symlink for easy access
RUN ln -s /usr/local/bin/orchat /usr/bin/orchat

# Create volume for configuration
VOLUME ["/root/.config"]

# Default command
CMD ["orchat", "--help"]
DOCKERFILE
    
    # Copy files
    cp -r bin/ config/ src/ "$docker_dir/"
    
    # Build Docker image
    if command -v docker &>/dev/null; then
        docker build -t "orchat:$VERSION" -t "orchat:latest" "$docker_dir"
        print_success "Docker image built: orchat:$VERSION"
        
        # Save image to file
        docker save "orchat:$VERSION" | gzip > "$DIST_DIR/orchat-$VERSION-docker.tar.gz"
        print_success "Docker image saved: $DIST_DIR/orchat-$VERSION-docker.tar.gz"
    else
        print_warning "Docker not available, creating Dockerfile only"
        cp "$docker_dir/Dockerfile" "$DIST_DIR/Dockerfile"
    fi
}

# Build Homebrew formula (macOS)
build_homebrew() {
    print_header "BUILDING HOMEBREW FORMULA"
    
    local formula_file="$DIST_DIR/orchat.rb"
    
    cat > "$formula_file" << FORMULA
class Orchat < Formula
  desc "Intelligent CLI chat interface with multi-turn conversations"
  homepage "https://github.com/orchat/orchat"
  url "https://github.com/orchat/orchat/releases/download/v#{version}/orchat-#{version}.tar.gz"
  version "$VERSION"
  sha256 "TODO_REPLACE_WITH_ACTUAL_SHA256"
  
  depends_on "bash"
  depends_on "curl"
  depends_on "jq"
  
  def install
    bin.install "bin/orchat"
    pkgshare.install "src"
    etc.install "config/orchat.toml.example" => "orchat/orchat.toml.example"
  end
  
  def post_install
    ohai "ORCHAT #{version} installed successfully!"
    ohai ""
    ohai "To get started:"
    ohai "  1. Configure API key:"
    ohai "     cp #{etc}/orchat/orchat.toml.example ~/.config/orchat.toml"
    ohai "     # Edit with your API key"
    ohai ""
    ohai "  2. Run ORCHAT:"
    ohai "     orchat 'Hello, world!'"
    ohai ""
    ohai "  3. Check system health:"
    ohai "     orchat doctor"
  end
  
  test do
    system "#{bin}/orchat", "--version"
  end
end
FORMULA
    
    print_success "Homebrew formula created: $formula_file"
    print_warning "Remember to update SHA256 with actual value before release"
}

# Create standalone tarball
build_tarball() {
    print_header "BUILDING STANDALONE TARBALL"
    
    tar czf "$DIST_DIR/$PACKAGE_NAME-$VERSION-$OS-$ARCH.tar.gz" \
        --transform "s,^,$PACKAGE_NAME/," \
        bin/ config/ src/ LICENSE README.md
    
    print_success "Tarball created: $DIST_DIR/$PACKAGE_NAME-$VERSION-$OS-$ARCH.tar.gz"
}

# Generate checksums
generate_checksums() {
    print_header "GENERATING CHECKSUMS"
    
    pushd "$DIST_DIR" >/dev/null
    
    for file in *; do
        if [[ -f "$file" ]]; then
            sha256sum "$file" >> "SHA256SUMS"
            print_success "Checksum for: $file"
        fi
    done
    
    popd >/dev/null
}

# Main build process
main() {
    print_header "ORCHAT PACKAGING SYSTEM - PHASE 4.1"
    echo "Version: $VERSION"
    echo "OS: $OS"
    echo "Arch: $ARCH"
    
    clean_build
    
    # Build all package types
    build_debian
    build_rpm
    build_docker
    build_homebrew
    build_tarball
    generate_checksums
    
    print_header "PACKAGING COMPLETE"
    echo "All packages built in: $DIST_DIR"
    echo ""
    echo "Packages created:"
    ls -la "$DIST_DIR/" | tail -n +2
    
    echo ""
    print_success "Phase 4.1: Packaging systems implementation COMPLETE"
}

# Run main function
main "$@"
