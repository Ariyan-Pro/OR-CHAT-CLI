
Debian 12 (Bookworm) Validation
ORCHAT Enterprise Certification
Test Environment
OS: Debian GNU/Linux 12

Kernel: 6.1.0-xx-amd64

Architecture: x86_64

Shell: bash 5.2.15

Package Manager: apt 2.6.1

Prerequisites
bash
# Base dependencies
sudo apt-get update
sudo apt-get install -y curl jq python3 python3-pip

# Debian-specific packages
sudo apt-get install -y ca-certificates gnupg lsb-release
Installation Test
bash
# Package installation test
./validation/install/debian-package-install.sh

# Security/permissions test
./validation/install/permission-test.sh

# Observability test
./validation/observability/health-check-validation.sh
Known Issues
Older curl versions may need upgrade

Python 3.11 default, compatible with ORCHAT

Certification Status: ✅ FULLY SUPPORTED
Last Tested: $(date)
Test Engineer: Senior AI Engineer
Result: PASS
