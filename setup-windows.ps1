# ORCHAT Windows Setup Script
# Sets up ORCHAT for Windows 10/11 with WSL2

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  ORCHAT ENTERPRISE - WINDOWS SETUP" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "WARNING: Not running as administrator." -ForegroundColor Yellow
    Write-Host "Some setup steps may require admin privileges." -ForegroundColor Yellow
    Write-Host ""
}

# Step 1: Check WSL installation
Write-Host "Step 1: Checking WSL installation..." -ForegroundColor Green
$wslInstalled = Get-Command wsl -ErrorAction SilentlyContinue
if (-not $wslInstalled) {
    Write-Host "WSL is not installed. Installing..." -ForegroundColor Yellow
    
    if ($isAdmin) {
        # Enable WSL feature
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
        Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
        
        Write-Host "WSL features enabled. Please restart your computer." -ForegroundColor Yellow
        Write-Host "After restart, run: wsl --install -d Ubuntu-24.04" -ForegroundColor Cyan
    } else {
        Write-Host "Please run PowerShell as Administrator and execute:" -ForegroundColor Yellow
        Write-Host "  Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux" -ForegroundColor Cyan
        Write-Host "  Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform" -ForegroundColor Cyan
    }
} else {
    Write-Host "✅ WSL is installed." -ForegroundColor Green
    
    # Check WSL version
    $wslVersion = wsl --version 2>$null
    if ($wslVersion -match "WSL 2") {
        Write-Host "✅ Using WSL 2." -ForegroundColor Green
    } else {
        Write-Host "⚠️  Consider upgrading to WSL 2 for better performance." -ForegroundColor Yellow
        Write-Host "   Run: wsl --set-version Ubuntu-24.04 2" -ForegroundColor Cyan
    }
}

# Step 2: Check Ubuntu installation
Write-Host ""
Write-Host "Step 2: Checking Ubuntu installation..." -ForegroundColor Green
$ubuntuInstalled = wsl -l -q | Select-String "Ubuntu"
if ($ubuntuInstalled) {
    Write-Host "✅ Ubuntu is installed in WSL." -ForegroundColor Green
} else {
    Write-Host "Ubuntu is not installed in WSL." -ForegroundColor Yellow
    Write-Host "Installing Ubuntu 24.04..." -ForegroundColor Cyan
    
    # Install Ubuntu from Microsoft Store
    Start-Process "ms-windows-store://pdp/?productid=9PDXGNCFSCZV"
    
    Write-Host "Please install Ubuntu 24.04 from the Microsoft Store." -ForegroundColor Yellow
    Write-Host "After installation, launch Ubuntu once to complete setup." -ForegroundColor Cyan
}

# Step 3: Setup ORCHAT in WSL
Write-Host ""
Write-Host "Step 3: Setting up ORCHAT in WSL..." -ForegroundColor Green
Write-Host "Opening WSL terminal to install ORCHAT..." -ForegroundColor Cyan

# Create a bash script to run in WSL
$wslScript = @"
#!/bin/bash
echo '=== ORCHAT WSL Setup ==='

# Update packages
sudo apt-get update
sudo apt-get install -y curl jq python3

# Install ORCHAT
mkdir -p ~/.local/bin
curl -L https://raw.githubusercontent.com/orchat/enterprise/main/bin/orchat -o ~/.local/bin/orchat
chmod +x ~/.local/bin/orchat

# Add to PATH
echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc
source ~/.bashrc

# Test installation
orchat --version
echo 'ORCHAT installation complete!'
"@

# Save script to temp file and run in WSL
$tempScript = [System.IO.Path]::GetTempFileName() + ".sh"
$wslScript | Out-File -FilePath $tempScript -Encoding UTF8

Write-Host "Running setup script in WSL..." -ForegroundColor Cyan
wsl bash -c "bash '$tempScript'"

# Clean up
Remove-Item $tempScript

# Step 4: Create Windows shortcuts
Write-Host ""
Write-Host "Step 4: Creating Windows shortcuts..." -ForegroundColor Green

# Create desktop shortcut
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\ORCHAT.lnk")
$Shortcut.TargetPath = "powershell.exe"
$Shortcut.Arguments = "-NoExit -File `"$PWD\orchat.ps1`""
$Shortcut.WorkingDirectory = $PWD
$Shortcut.Description = "ORCHAT Enterprise AI Assistant"
$Shortcut.IconLocation = "$PWD\assets\orchat.ico, 0"
$Shortcut.Save()

Write-Host "✅ Desktop shortcut created." -ForegroundColor Green

# Step 5: Add to PATH
Write-Host ""
Write-Host "Step 5: Adding ORCHAT to Windows PATH..." -ForegroundColor Green

$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
$orchatDir = $PWD

if ($userPath -notlike "*$orchatDir*") {
    [Environment]::SetEnvironmentVariable("PATH", "$userPath;$orchatDir", "User")
    Write-Host "✅ Added ORCHAT directory to user PATH." -ForegroundColor Green
} else {
    Write-Host "✅ ORCHAT directory already in PATH." -ForegroundColor Green
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  SETUP COMPLETE!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "You can now use ORCHAT in several ways:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Double-click ORCHAT.lnk on your desktop" -ForegroundColor Cyan
Write-Host "2. Run: .\orchat.bat from PowerShell/CMD" -ForegroundColor Cyan
Write-Host "3. Run: .\orchat.ps1 from PowerShell" -ForegroundColor Cyan
Write-Host "4. Run: orchat from WSL terminal" -ForegroundColor Cyan
Write-Host ""
Write-Host "To set your API key:" -ForegroundColor Yellow
Write-Host "  In WSL: export OPENROUTER_API_KEY='your-key-here'" -ForegroundColor Cyan
Write-Host "  In Windows: setx OPENROUTER_API_KEY 'your-key-here'" -ForegroundColor Cyan
Write-Host ""
Write-Host "Enjoy ORCHAT Enterprise!" -ForegroundColor Green
pause
