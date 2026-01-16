# ORCHAT PowerShell Wrapper
# Provides better Windows integration

param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

# Check WSL installation
if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Windows Subsystem for Linux (WSL) is not installed." -ForegroundColor Red
    Write-Host "Please install WSL from Microsoft Store." -ForegroundColor Yellow
    Write-Host "Instructions: https://docs.microsoft.com/en-us/windows/wsl/install" -ForegroundColor Cyan
    pause
    exit 1
}

# Convert Windows path to WSL path
$CurrentDir = (Get-Location).Path
$WslPath = $CurrentDir -replace '^([A-Z]):', '/mnt/${1}' -replace '\\', '/'

# Prepare arguments for WSL
$WslArgs = @()
foreach ($arg in $Arguments) {
    # Escape single quotes for bash
    $escapedArg = $arg -replace "'", "''"
    $WslArgs += "'$escapedArg'"
}

# Join arguments
$ArgumentString = $WslArgs -join ' '

Write-Host "ORCHAT Enterprise - Windows/WSL Bridge" -ForegroundColor Cyan
Write-Host "Running in WSL from: $WslPath" -ForegroundColor Gray
Write-Host ""

# Execute in WSL
wsl -d Ubuntu-24.04 bash -c "cd '$WslPath' && ~/.local/bin/orchat $ArgumentString"
