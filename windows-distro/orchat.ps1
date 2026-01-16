#!/usr/bin/env pwsh
<#
.SYNOPSIS
    ORCHAT Enterprise AI Assistant - PowerShell Wrapper
.DESCRIPTION
    PowerShell wrapper for ORCHAT running in WSL2
.EXAMPLE
    .\orchat.ps1 "What is the meaning of life?"
    .\orchat.ps1 --help
#>

param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

# Check if WSL is available
if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
    Write-Error "WSL (Windows Subsystem for Linux) is not installed."
    Write-Host "Please install WSL first:" -ForegroundColor Yellow
    Write-Host "https://docs.microsoft.com/en-us/windows/wsl/install" -ForegroundColor Cyan
    exit 1
}

# Build the command
$command = "orchat"
if ($Arguments) {
    $command += " '$($Arguments -join " ")'"
}

# Execute in WSL
try {
    wsl $command
    exit $LASTEXITCODE
} catch {
    Write-Error "Failed to execute ORCHAT: $_"
    exit 1
}
