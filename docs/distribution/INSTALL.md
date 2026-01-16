# ORCHAT Installation Guide

## Quick Installation

### Debian/Ubuntu (Recommended)
```bash
# Download latest release
curl -L https://github.com/orchat/enterprise/releases/latest/download/orchat_latest_all.deb -o orchat.deb

# Install
sudo dpkg -i orchat.deb

# Install dependencies if needed
sudo apt-get install -f
macOS (Homebrew)
bash
# Tap the repository
brew tap orchat/enterprise

# Install
brew install orchat
Windows (WSL2 Required)
Download install.bat from releases

Run as Administrator

Use from PowerShell: orchat "Your prompt"

Docker
bash
# Pull from Docker Hub
docker pull orchat/enterprise:latest

# Run
docker run -it orchat/enterprise "Your prompt"
PyPI (Python Package)
bash
pip install orchat-enterprise

# Use
orchat "Your prompt"
Manual Installation
From Source
bash
git clone https://github.com/orchat/enterprise.git
cd enterprise

# Run directly
./bin/orchat "Your prompt"

# Or install globally
sudo cp bin/orchat /usr/local/bin/
sudo cp -r src /usr/local/lib/orchat/
Configuration
API Key Setup
bash
# Method 1: Environment variable
export OPENROUTER_API_KEY="your-key-here"

# Method 2: Config file
echo "your-key-here" > ~/.config/orchat/config

# Method 3: Secure storage (recommended)
mkdir -p ~/.config/orchat
chmod 700 ~/.config/orchat
echo "get_api_key() { echo 'your-key-here'; }" > ~/.config/orchat/secure_key.sh
chmod 500 ~/.config/orchat/secure_key.sh
Verification
bash
# Check installation
orchat --version

# Run validation tests
cd /usr/share/doc/orchat && ./validation/run-all.sh

# Test with a simple prompt
orchat "Hello, world!"
Troubleshooting
Common Issues
Permission Denied

bash
chmod +x bin/orchat
Missing Dependencies

bash
sudo apt-get install curl jq python3
API Key Not Found

bash
echo "OPENROUTER_API_KEY=your-key" >> ~/.bashrc
source ~/.bashrc
Support
GitHub Issues: https://github.com/orchat/enterprise/issues

Documentation: https://orchat.ai/docs

Community: Discord (link in README)
