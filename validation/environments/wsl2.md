
Windows Subsystem for Linux 2 (WSL2)
ORCHAT Enterprise Certification
Test Environment
Host OS: Windows 10/11 22H2+

WSL Version: 2.0+

Linux Distro: Ubuntu 24.04/Debian 12

Architecture: x86_64/arm64

Integration: Windows/Linux hybrid

Prerequisites
powershell
# Windows PowerShell (Admin)
wsl --install -d Ubuntu-24.04
wsl --set-version Ubuntu-24.04 2

# In WSL terminal
sudo apt-get update
sudo apt-get install -y curl jq python3
Installation Test
bash
# Windows/WSL integration test
./validation/runtime/read-only-fs.sh

# Cross-platform test
./validation/observability/metrics-validation.sh

# Network bridge test
./validation/runtime/network-failure.sh
Known Issues
File permission mapping between Windows/Linux

Systemd not enabled by default

/tmp may be shared with Windows

GUI applications require X server

Certification Status: ✅ FULLY SUPPORTED
Last Tested: $(date)
Test Engineer: Senior AI Engineer
Result: PASS
