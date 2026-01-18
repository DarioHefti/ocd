#
# setup.ps1 - One-time setup for opencode-docker (PowerShell)
#
# This script will:
#   1. Build the Docker image
#   2. Create the opencode config directory if it doesn't exist
#   3. Add the 'ocd' alias to your PowerShell profile
#
# After running this script, you can use 'ocd' from anywhere to launch opencode in Docker.
#

$ErrorActionPreference = "Stop"

# Get the directory where this script is located
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$ImageName = "opencode-container:latest"
$AliasName = "ocd"

function Write-Step { param($Message) Write-Host "[STEP] $Message" -ForegroundColor Blue }
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Green }
function Write-Warn { param($Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Err { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

Write-Host ""
Write-Host "========================================"
Write-Host "  OpenCode Docker Setup (PowerShell)"
Write-Host "========================================"
Write-Host ""

# Check if Docker is installed
Write-Step "Checking Docker..."
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Err "Docker is not installed. Please install Docker Desktop first."
    exit 1
}

# Check if Docker is running
$dockerInfo = docker info 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Err "Docker is not running. Please start Docker Desktop and try again."
    exit 1
}
Write-Info "Docker is available."

# Build the Docker image
Write-Step "Building Docker image (this may take a few minutes)..."
docker build -t $ImageName $ScriptDir
if ($LASTEXITCODE -ne 0) {
    Write-Err "Failed to build Docker image."
    exit 1
}
Write-Info "Docker image built successfully."

# Create config directory if needed
Write-Step "Checking config directory..."
$ConfigDir = Join-Path $env:USERPROFILE ".config\opencode"
if (-not (Test-Path $ConfigDir)) {
    Write-Info "Creating config directory at $ConfigDir"
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
} else {
    Write-Info "Config directory already exists at $ConfigDir"
}

# Create data directory if needed
Write-Step "Checking data directory..."
$DataDir = Join-Path $env:USERPROFILE ".local\share\opencode"
if (-not (Test-Path $DataDir)) {
    Write-Info "Creating data directory at $DataDir"
    New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
} else {
    Write-Info "Data directory already exists at $DataDir"
}

# Set up PowerShell profile with ocd function
Write-Step "Setting up PowerShell profile..."

$LauncherPath = Join-Path $ScriptDir "opencode-docker.ps1"

# The function to add to the profile
$FunctionDefinition = @"

# OpenCode Docker function
function $AliasName {
    & "$LauncherPath" @args
}
"@

# Ensure profile exists
if (-not (Test-Path $PROFILE)) {
    Write-Info "Creating PowerShell profile at $PROFILE"
    $ProfileDir = Split-Path -Parent $PROFILE
    if (-not (Test-Path $ProfileDir)) {
        New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
    }
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}

# Check if function already exists
$ProfileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
if ($ProfileContent -match "function $AliasName") {
    # Check if it points to the correct path
    if ($ProfileContent -match [regex]::Escape($LauncherPath)) {
        Write-Info "Function '$AliasName' already configured correctly in profile."
    } else {
        Write-Warn "Updating existing '$AliasName' function in profile..."
        # Remove old function definition (handles multi-line)
        $ProfileContent = $ProfileContent -replace "(?ms)# OpenCode Docker function\r?\nfunction $AliasName \{[^}]+\}\r?\n?", ""
        $ProfileContent = $ProfileContent.TrimEnd() + $FunctionDefinition
        Set-Content -Path $PROFILE -Value $ProfileContent
        Write-Info "Updated function in $PROFILE"
    }
} else {
    # Add the function
    Add-Content -Path $PROFILE -Value $FunctionDefinition
    Write-Info "Added function to $PROFILE"
}

Write-Host ""
Write-Host "========================================"
Write-Host "  Setup Complete!"
Write-Host "========================================"
Write-Host ""
Write-Host "Usage:"
Write-Host ""
Write-Host "  $AliasName                        " -NoNewline -ForegroundColor Green
Write-Host "- Run opencode in current directory"
Write-Host "  $AliasName -c C:\path\to\config   " -NoNewline -ForegroundColor Green
Write-Host "- Use custom config directory"
Write-Host "  $AliasName -w C:\path\to\project  " -NoNewline -ForegroundColor Green
Write-Host "- Run in specific directory"
Write-Host "  $AliasName -s                     " -NoNewline -ForegroundColor Green
Write-Host "- Start a shell in the container"
Write-Host "  $AliasName -b                     " -NoNewline -ForegroundColor Green
Write-Host "- Force rebuild the image"
Write-Host "  $AliasName -h                     " -NoNewline -ForegroundColor Green
Write-Host "- Show all options"
Write-Host ""
Write-Host "To use the function now, either:"
Write-Host "  1. Open a new PowerShell window, or"
Write-Host "  2. Run: " -NoNewline
Write-Host ". `$PROFILE" -ForegroundColor Yellow
Write-Host ""
