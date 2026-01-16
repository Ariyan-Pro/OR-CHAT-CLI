
ORCHAT Installation Guide
5-Minute Enterprise Installation
Quick Start
bash
# One-line install (Unix/Linux/macOS/WSL)
curl -fsSL https://orchat.ai/install.sh | bash

# Verify installation
orchat --version
Detailed Installation
1. Prerequisites
bash
# Required dependencies
sudo apt-get update  # Debian/Ubuntu
sudo apt-get install -y curl jq python3

# Or on macOS
brew install curl jq python3

# Or on Arch
sudo pacman -S curl jq python
2. Manual Installation
bash
# Download ORCHAT
curl -L https://github.com/orchat/enterprise/releases/latest/download/orchat-linux-amd64 -o /tmp/orchat
chmod +x /tmp/orchat
sudo mv /tmp/orchat /usr/local/bin/

# Or install to user directory
mkdir -p ~/.local/bin
curl -L https://github.com/orchat/enterprise/releases/latest/download/orchat-linux-amd64 -o ~/.local/bin/orchat
chmod +x ~/.local/bin/orchat
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
3. API Key Configuration
bash
# Method 1: Environment variable
export OPENROUTER_API_KEY="sk-or-your-key-here"

# Method 2: Config file
mkdir -p ~/.config/orchat
echo "sk-or-your-key-here" > ~/.config/orchat/config
chmod 600 ~/.config/orchat/config

# Method 3: Interactive setup
orchat --setup
4. Verify Installation
bash
# Check version
orchat --version

# Test basic functionality
orchat "Hello, world!"

# Run health check
orchat health-check
Platform-Specific Instructions
Ubuntu/Debian (apt)
bash
# Add repository
curl -fsSL https://orchat.ai/gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/orchat-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/orchat-archive-keyring.gpg] https://repo.orchat.ai stable main" | sudo tee /etc/apt/sources.list.d/orchat.list

# Install
sudo apt-get update
sudo apt-get install orchat
macOS (Homebrew)
bash
# Tap repository
brew tap orchat/enterprise

# Install
brew install orchat

# Or cask for GUI version
brew install --cask orchat
Windows (WSL2)
powershell
# In PowerShell (Admin)
wsl --install -d Ubuntu-24.04

# In WSL terminal
curl -fsSL https://orchat.ai/install.sh | bash
Troubleshooting
Permission Denied
bash
chmod +x ~/.local/bin/orchat
Command Not Found
bash
# Add to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
API Key Issues
bash
# Reset configuration
rm -rf ~/.config/orchat
orchat --setup
Next Steps
Run validation suite: ./validation/run-all.sh

Configure workspace: orchat workspace setup

Set up monitoring: orchat metrics enable

Support
Documentation: https://docs.orchat.ai

Issues: https://github.com/orchat/enterprise/issues

Community: https://discord.gg/orchat
