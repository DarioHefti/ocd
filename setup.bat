@echo off
setlocal EnableDelayedExpansion
REM
REM setup.bat - One-time setup for opencode-docker (Windows)
REM
REM This script will:
REM   1. Build the Docker image
REM   2. Create the opencode config directory if it doesn't exist
REM   3. Add opencode-docker to your PATH (optional)
REM
REM After running this script, you can use 'ocd' from anywhere to launch opencode in Docker.
REM

REM Get the directory where this script is located
set "SCRIPT_DIR=%~dp0"
REM Remove trailing backslash
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

set "IMAGE_NAME=opencode-container:latest"
set "ALIAS_NAME=ocd"

echo.
echo ========================================
echo   OpenCode Docker Setup (Windows)
echo ========================================
echo.

REM Check if Docker is installed
echo [STEP] Checking Docker...
where docker >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker is not installed. Please install Docker Desktop first.
    exit /b 1
)

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker is not running. Please start Docker Desktop and try again.
    exit /b 1
)
echo [INFO] Docker is available.

REM Build the Docker image
echo [STEP] Building Docker image (this may take a few minutes)...
docker build -t "%IMAGE_NAME%" "%SCRIPT_DIR%"
if errorlevel 1 (
    echo [ERROR] Failed to build Docker image.
    exit /b 1
)
echo [INFO] Docker image built successfully.

REM Create config directory if needed
echo [STEP] Checking config directory...
set "CONFIG_DIR=%USERPROFILE%\.config\opencode"
if not exist "%CONFIG_DIR%" (
    echo [INFO] Creating config directory at %CONFIG_DIR%
    mkdir "%CONFIG_DIR%"
) else (
    echo [INFO] Config directory already exists at %CONFIG_DIR%
)

REM Create data directory if needed
echo [STEP] Checking data directory...
set "DATA_DIR=%USERPROFILE%\.local\share\opencode"
if not exist "%DATA_DIR%" (
    echo [INFO] Creating data directory at %DATA_DIR%
    mkdir "%DATA_DIR%"
) else (
    echo [INFO] Data directory already exists at %DATA_DIR%
)

REM Create ocd.bat wrapper in the same directory
echo [STEP] Creating shortcut command...
set "OCD_BAT=%SCRIPT_DIR%\ocd.bat"
(
    echo @echo off
    echo setlocal
    echo call "%SCRIPT_DIR%\opencode-docker.bat" %%*
    echo endlocal
) > "%OCD_BAT%"
echo [INFO] Created %OCD_BAT%

REM Check if script directory is in PATH
echo [STEP] Checking PATH configuration...
echo %PATH% | findstr /i /c:"%SCRIPT_DIR%" >nul 2>&1
if errorlevel 1 (
    echo.
    echo [WARN] The script directory is not in your PATH.
    echo.
    echo To use 'ocd' from anywhere, you have two options:
    echo.
    echo Option 1: Add to PATH manually
    echo   1. Press Win+X, select "System"
    echo   2. Click "Advanced system settings"
    echo   3. Click "Environment Variables"
    echo   4. Under "User variables", select "Path" and click "Edit"
    echo   5. Click "New" and add: %SCRIPT_DIR%
    echo   6. Click OK to save
    echo.
    echo Option 2: Add to PATH via command line (requires admin)
    echo   Run this command in an Administrator PowerShell:
    echo   [Environment]::SetEnvironmentVariable("Path", $env:Path + ";%SCRIPT_DIR%", "User")
    echo.
    
    set /p "ADD_PATH=Would you like to add to PATH now? (requires new terminal) [Y/n]: "
    if /i "!ADD_PATH!"=="" set "ADD_PATH=Y"
    if /i "!ADD_PATH!"=="Y" (
        REM Add to user PATH using setx
        for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "CURRENT_PATH=%%b"
        if "!CURRENT_PATH!"=="" (
            setx PATH "%SCRIPT_DIR%" >nul 2>&1
        ) else (
            REM Check if already in path (case insensitive)
            echo !CURRENT_PATH! | findstr /i /c:"%SCRIPT_DIR%" >nul 2>&1
            if errorlevel 1 (
                setx PATH "!CURRENT_PATH!;%SCRIPT_DIR%" >nul 2>&1
            )
        )
        if errorlevel 1 (
            echo [ERROR] Failed to update PATH. Please add manually.
        ) else (
            echo [INFO] PATH updated. Please open a new terminal for changes to take effect.
        )
    )
) else (
    echo [INFO] Script directory is already in PATH.
)

echo.
echo ========================================
echo   Setup Complete!
echo ========================================
echo.
echo Usage:
echo.
echo   ocd                        - Run opencode in current directory
echo   ocd -c C:\path\to\config   - Use custom config directory
echo   ocd -w C:\path\to\project  - Run in specific directory
echo   ocd -s                     - Start a shell in the container
echo   ocd -b                     - Force rebuild the image
echo   ocd -h                     - Show all options
echo.
echo If 'ocd' is not found, you can also run:
echo   "%SCRIPT_DIR%\opencode-docker.bat"
echo.
echo Or open a new terminal if you added the directory to PATH.
echo.
echo NOTE: These scripts work in both CMD and PowerShell.
echo       In PowerShell, you may need to run: cmd /c ocd
echo       Or add a PowerShell alias: Set-Alias ocd "%SCRIPT_DIR%\ocd.bat"
echo.

endlocal
