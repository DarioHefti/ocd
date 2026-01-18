@echo off
setlocal EnableDelayedExpansion
REM
REM opencode-docker.bat - Run opencode in an isolated Docker container (Windows)
REM
REM Usage:
REM   opencode-docker.bat [OPTIONS] [-- OPENCODE_ARGS...]
REM
REM Options:
REM   -c, --config PATH    Use custom config directory (overrides %USERPROFILE%\.config\opencode)
REM   -d, --data PATH      Use custom data directory (overrides %USERPROFILE%\.local\share\opencode)
REM   -w, --workdir PATH   Use custom working directory (default: current directory)
REM   -b, --build          Force rebuild the Docker image before running
REM   -s, --shell          Start a shell instead of opencode
REM   -h, --help           Show this help message
REM
REM Examples:
REM   opencode-docker.bat                           # Run in current directory
REM   opencode-docker.bat -c C:\path\to\config      # Use custom config
REM   opencode-docker.bat -w C:\path\to\project     # Run in specific directory
REM   opencode-docker.bat -s                        # Start shell for debugging
REM   opencode-docker.bat -- --help                 # Pass args to opencode
REM

REM Get the directory where this script is located
set "SCRIPT_DIR=%~dp0"
REM Remove trailing backslash
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

REM Defaults
set "WORK_DIR=%CD%"
set "CONFIG_DIR=%USERPROFILE%\.config\opencode"
set "DATA_DIR=%USERPROFILE%\.local\share\opencode"
set "FORCE_BUILD=false"
set "START_SHELL=false"
set "IMAGE_NAME=opencode-container:latest"
set "OPENCODE_ARGS="

REM Parse arguments
:parse_args
if "%~1"=="" goto :done_args
if "%~1"=="-c" goto :set_config
if "%~1"=="--config" goto :set_config
if "%~1"=="-d" goto :set_data
if "%~1"=="--data" goto :set_data
if "%~1"=="-w" goto :set_workdir
if "%~1"=="--workdir" goto :set_workdir
if "%~1"=="-b" goto :set_build
if "%~1"=="--build" goto :set_build
if "%~1"=="-s" goto :set_shell
if "%~1"=="--shell" goto :set_shell
if "%~1"=="-h" goto :show_help
if "%~1"=="--help" goto :show_help
if "%~1"=="--" goto :collect_opencode_args
echo [ERROR] Unknown option: %~1
goto :show_help

:set_config
if "%~2"=="" (
    echo [ERROR] Option %~1 requires a path argument
    exit /b 1
)
set "CONFIG_DIR=%~2"
shift
shift
goto :parse_args

:set_data
if "%~2"=="" (
    echo [ERROR] Option %~1 requires a path argument
    exit /b 1
)
set "DATA_DIR=%~2"
shift
shift
goto :parse_args

:set_workdir
if "%~2"=="" (
    echo [ERROR] Option %~1 requires a path argument
    exit /b 1
)
set "WORK_DIR=%~2"
shift
shift
goto :parse_args

:set_build
set "FORCE_BUILD=true"
shift
goto :parse_args

:set_shell
set "START_SHELL=true"
shift
goto :parse_args

:collect_opencode_args
shift
:collect_loop
if "%~1"=="" goto :done_args
if "!OPENCODE_ARGS!"=="" (
    set "OPENCODE_ARGS=%~1"
) else (
    set "OPENCODE_ARGS=!OPENCODE_ARGS! %~1"
)
shift
goto :collect_loop

:done_args

REM Validate working directory
if not exist "%WORK_DIR%" (
    echo [ERROR] Working directory does not exist: %WORK_DIR%
    exit /b 1
)

REM Convert to absolute paths
pushd "%WORK_DIR%"
set "WORK_DIR=%CD%"
popd

REM Create config directory if it doesn't exist
if not exist "%CONFIG_DIR%" (
    echo [WARN] Config directory does not exist: %CONFIG_DIR%
    echo [INFO] Creating config directory...
    mkdir "%CONFIG_DIR%"
)
pushd "%CONFIG_DIR%"
set "CONFIG_DIR=%CD%"
popd

REM Create data directory if it doesn't exist
if not exist "%DATA_DIR%" (
    echo [WARN] Data directory does not exist: %DATA_DIR%
    echo [INFO] Creating data directory...
    mkdir "%DATA_DIR%"
)
pushd "%DATA_DIR%"
set "DATA_DIR=%CD%"
popd

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker is not running. Please start Docker and try again.
    exit /b 1
)

REM Check if image exists or force build
set "IMAGE_EXISTS="
for /f "tokens=*" %%i in ('docker images -q "%IMAGE_NAME%" 2^>nul') do set "IMAGE_EXISTS=%%i"

if "%IMAGE_EXISTS%"=="" set "NEED_BUILD=true"
if "%FORCE_BUILD%"=="true" set "NEED_BUILD=true"

if "%NEED_BUILD%"=="true" (
    echo [INFO] Building Docker image...
    
    if not exist "%SCRIPT_DIR%\Dockerfile" (
        echo [ERROR] Dockerfile not found at %SCRIPT_DIR%\Dockerfile
        exit /b 1
    )
    
    docker build -t "%IMAGE_NAME%" "%SCRIPT_DIR%"
    if errorlevel 1 (
        echo [ERROR] Failed to build Docker image.
        exit /b 1
    )
    echo [INFO] Docker image built successfully.
)

REM Container user home directory
set "CONTAINER_HOME=/root"

REM Show what we're doing
echo [INFO] Work directory: %WORK_DIR%
echo [INFO] Config directory: %CONFIG_DIR%
echo [INFO] Data directory: %DATA_DIR%

REM Build and run docker command directly (avoids quote issues in PowerShell)
REM We use call to ensure proper execution in both CMD and PowerShell

set "AGENTS_MOUNT="
if exist "%SCRIPT_DIR%\AGENTS.md" (
    set "AGENTS_MOUNT=-v "%SCRIPT_DIR%\AGENTS.md:%CONTAINER_HOME%/.config/opencode/AGENTS.md:ro""
)

set "ENV_VARS="
if defined ANTHROPIC_API_KEY set "ENV_VARS=!ENV_VARS! -e ANTHROPIC_API_KEY=!ANTHROPIC_API_KEY!"
if defined OPENAI_API_KEY set "ENV_VARS=!ENV_VARS! -e OPENAI_API_KEY=!OPENAI_API_KEY!"

if "%START_SHELL%"=="true" (
    echo [INFO] Starting shell in container...
    docker run --rm -it ^
        -v "%WORK_DIR%:/work" ^
        -v "%CONFIG_DIR%:%CONTAINER_HOME%/.config/opencode" ^
        -v "%DATA_DIR%:%CONTAINER_HOME%/.local/share/opencode" ^
        %AGENTS_MOUNT% ^
        -w /work ^
        -e TERM=xterm-256color ^
        %ENV_VARS% ^
        %IMAGE_NAME% /bin/bash
) else (
    docker run --rm -it ^
        -v "%WORK_DIR%:/work" ^
        -v "%CONFIG_DIR%:%CONTAINER_HOME%/.config/opencode" ^
        -v "%DATA_DIR%:%CONTAINER_HOME%/.local/share/opencode" ^
        %AGENTS_MOUNT% ^
        -w /work ^
        -e TERM=xterm-256color ^
        %ENV_VARS% ^
        %IMAGE_NAME% opencode !OPENCODE_ARGS!
)
goto :eof

:show_help
echo.
echo opencode-docker.bat - Run opencode in an isolated Docker container
echo.
echo Usage:
echo   opencode-docker.bat [OPTIONS] [-- OPENCODE_ARGS...]
echo.
echo Options:
echo   -c, --config PATH    Use custom config directory
echo   -d, --data PATH      Use custom data directory
echo   -w, --workdir PATH   Use custom working directory (default: current directory)
echo   -b, --build          Force rebuild the Docker image before running
echo   -s, --shell          Start a shell instead of opencode
echo   -h, --help           Show this help message
echo.
echo Examples:
echo   opencode-docker.bat                           Run in current directory
echo   opencode-docker.bat -c C:\path\to\config      Use custom config
echo   opencode-docker.bat -w C:\path\to\project     Run in specific directory
echo   opencode-docker.bat -s                        Start shell for debugging
echo   opencode-docker.bat -- --help                 Pass args to opencode
echo.
exit /b 0
