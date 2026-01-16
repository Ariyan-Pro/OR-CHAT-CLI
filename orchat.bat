@echo off
REM ORCHAT for Windows
REM This batch file runs ORCHAT in WSL

setlocal enabledelayedexpansion

REM Check if WSL is available
where wsl >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: Windows Subsystem for Linux (WSL) is not installed.
    echo Please install WSL from Microsoft Store.
    pause
    exit /b 1
)

REM Get the current directory in Windows format
set "WIN_DIR=%~dp0"
set "WIN_DIR=%WIN_DIR:~0,-1%"

REM Convert Windows path to WSL path
set "WSL_DIR=%WIN_DIR:\=\\%"
set "WSL_DIR=%WSL_DIR:C:=/mnt/c%"
set "WSL_DIR=%WSL_DIR:c:=/mnt/c%"

REM Pass arguments to WSL
set "ARGS="
for %%a in (%*) do (
    set "ARG=%%a"
    set "ARG=!ARG:\=\\!"
    set "ARG=!ARG:'=''!"
    set "ARGS=!ARGS! '!ARG!'"
)

REM Run ORCHAT in WSL
wsl -d Ubuntu-24.04 bash -c "cd '%WSL_DIR%' && ~/.local/bin/orchat %ARGS%"
