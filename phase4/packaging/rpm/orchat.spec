Name: orchat
Version: 0.3.0
Release: 1%{?dist}
Summary: OpenRouter CLI with multi-turn chat and streaming
License: MIT
URL: https://github.com/orchat/orchat
Source0: orchat-%{version}.tar.gz

BuildArch: noarch
Requires: bash >= 4.0, python3, jq, curl

%description
ORCHAT is a production-grade CLI for interacting with OpenRouter AI models.
It features persistent conversations, robust streaming, and enterprise controls.

%prep
%setup -q

%build
# Nothing to build - it's a Bash/Python script

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/usr/bin
mkdir -p %{buildroot}/usr/lib/orchat
mkdir -p %{buildroot}/usr/share/doc/orchat
mkdir -p %{buildroot}/etc/orchat
mkdir -p %{buildroot}/usr/share/orchat/data

# Install binaries
install -m 755 bin/orchat %{buildroot}/usr/bin/
install -m 755 bin/orchat.robust %{buildroot}/usr/bin/orchat-robust

# Install modules
install -m 755 src/*.sh %{buildroot}/usr/lib/orchat/

# Install configuration
install -m 644 config/orchat.toml %{buildroot}/etc/orchat/orchat.toml.dist
install -m 644 config/schema.json %{buildroot}/usr/share/doc/orchat/

# Install data files
cp -r data/* %{buildroot}/usr/share/orchat/data/ 2>/dev/null || true

# Create examples
mkdir -p %{buildroot}/usr/share/doc/orchat/examples
cat > %{buildroot}/usr/share/doc/orchat/examples/basic-usage.sh << 'EXAMPLES_EOF'
#!/bin/bash
echo "ORCHAT RPM Package Installed!"
echo ""
echo "Quick Start:"
echo "1. Set API key: mkdir -p ~/.config/orchat && echo 'key' > ~/.config/orchat/config"
echo "2. Test: orchat 'Hello from RPM!' --no-stream"
echo "3. Interactive: orchat -i"
EXAMPLES_EOF
chmod 755 %{buildroot}/usr/share/doc/orchat/examples/basic-usage.sh

%post
echo "ORCHAT installed successfully!"
echo ""
echo "To get started:"
echo "1. Set your API key:"
echo "   mkdir -p ~/.config/orchat"
echo "   echo 'your-api-key-here' > ~/.config/orchat/config"
echo "   chmod 600 ~/.config/orchat/config"
echo "2. Run: orchat --help"

%preun
if [ $1 -eq 0 ]; then
    echo "Removing ORCHAT..."
    echo "User configs in ~/.config/orchat/ will remain"
fi

%files
%doc README.md
%license LICENSE
%dir /usr/lib/orchat
%dir /etc/orchat
%dir /usr/share/orchat
%dir /usr/share/doc/orchat
/usr/bin/orchat
/usr/bin/orchat-robust
/usr/lib/orchat/*.sh
/etc/orchat/orchat.toml.dist
/usr/share/doc/orchat/schema.json
/usr/share/doc/orchat/examples/
/usr/share/orchat/data/

%changelog
* Sun Jan 12 2026 ORCHAT Team <orchat@example.com> - 0.3.0-1
- Initial RPM package for ORCHAT Phase 4
- Includes all 14 modules with Python safety
- Enterprise-ready configuration
