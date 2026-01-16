@echo off
REM ORCHAT Windows Batch Wrapper
REM This script requires WSL (Windows Subsystem for Linux)

where wsl >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: WSL not found.
    echo ORCHAT requires Windows Subsystem for Linux.
    echo Install WSL: https://docs.microsoft.com/en-us/windows/wsl/install
    exit /b 1
)

REM Get script directory
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

REM Convert Windows path to WSL path
for /f "delims=" %%i in ('wsl wslpath -a "%SCRIPT_DIR%"') do set "WSL_DIR=%%i"

REM Fix line endings for key files
powershell -Command "Get-Content '%SCRIPT_DIR%\bin\orchat' -Raw | ForEach-Object { $$_ -replace \"`r`n\", \"`n\" } | Set-Content '%SCRIPT_DIR%\bin\orchat' -NoNewline -Encoding UTF8"
powershell -Command "Get-Content '%SCRIPT_DIR%\bin\orchat.robust' -Raw | ForEach-Object { $$_ -replace \"`r`n\", \"`n\" } | Set-Content '%SCRIPT_DIR%\bin\orchat.robust' -NoNewline -Encoding UTF8"

REM Pass all arguments to WSL
set "ARGS=%*"
wsl bash -c "cd '%WSL_DIR%' && ./bin/orchat %ARGS%"
