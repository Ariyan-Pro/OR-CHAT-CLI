#!/usr/bin/env pwsh
# ORCHAT Windows PowerShell Wrapper

$ErrorActionPreference = "Stop"

# Fix line endings for WSL
function Fix-LineEndings {
    param([string]$Path)
    
    if (Test-Path $Path) {
        $content = Get-Content -Path $Path -Raw
        $content = $content -replace "`r`n", "`n"
        Set-Content -Path $Path -Value $content -NoNewline -Encoding UTF8
    }
}

# Find WSL path
$wslPath = "wsl"
if (Get-Command $wslPath -ErrorAction SilentlyContinue) {
    # Get project directory and convert to WSL path
    $projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $wslProjectDir = $wslPath + " wslpath -a '" + $projectDir + "'"
    $wslProjectDir = Invoke-Expression $wslProjectDir | Out-String
    
    # Fix line endings in key files
    Fix-LineEndings -Path "$projectDir\bin\orchat"
    Fix-LineEndings -Path "$projectDir\bin\orchat.robust"
    
    # Pass all arguments to WSL
    $argsString = $args -join " "
    $command = "$wslPath bash -c 'cd `"$wslProjectDir`" && ./bin/orchat $argsString'"
    
    Invoke-Expression $command
} else {
    Write-Error "WSL not found. ORCHAT requires Windows Subsystem for Linux."
    Write-Host "Install WSL: https://docs.microsoft.com/en-us/windows/wsl/install"
    exit 1
}
