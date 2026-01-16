#!/usr/bin/env pwsh
<#
.SYNOPSIS
    PowerShell wrapper for Orchat CLI
#>

# Convert Windows path to WSL path
$wslPath = "/mnt/c/Users/dell/Projects/orchat/bin/orchat"

# Pass all arguments
$argsString = $args -join " "
Invoke-Expression "wsl bash -c '$wslPath $argsString'"
