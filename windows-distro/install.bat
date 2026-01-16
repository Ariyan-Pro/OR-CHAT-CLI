@echo off
echo ========================================
echo    ORCHAT Enterprise AI Assistant
echo ========================================
echo.

REM Check for WSL
where wsl >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: Windows Subsystem for Linux (WSL) not found.
    echo Please install WSL first:
    echo   https://docs.microsoft.com/en-us/windows/wsl/install
    pause
    exit /b 1
)

echo Installing ORCHAT in WSL...
echo.

REM Run installation in WSL
wsl bash -c '
    echo "Installing ORCHAT in WSL..."
    
    # Create installation directory
    mkdir -p ~/.local/bin
    mkdir -p ~/.local/lib/orchat
    
    # Copy files from Windows
    cp -r /mnt/c/Users/dell/Projects/orchat/bin/* ~/.local/bin/
    cp -r /mnt/c/Users/dell/Projects/orchat/src/* ~/.local/lib/orchat/
    
    # Make executable
    chmod +x ~/.local/bin/orchat
    
    echo "✅ ORCHAT installed successfully!"
    echo ""
    echo "To use:"
    echo "   wsl orchat \"Your prompt here\""
    echo "   orchat \"Your prompt here\" (from WSL)"
'

echo.
echo Installation complete!
echo.
echo Usage examples:
echo   wsl orchat "Hello, how are you?"
echo   wsl orchat --help
echo.
pause
