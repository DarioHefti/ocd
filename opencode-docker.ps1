#
# opencode-docker.ps1 - Run opencode in an isolated Docker container (PowerShell)
#
# Usage:
#   opencode-docker.ps1 [OPTIONS] [-- OPENCODE_ARGS...]
#
# Options:
#   -c, -config PATH    Use custom config directory
#   -d, -data PATH      Use custom data directory
#   -w, -workdir PATH   Use custom working directory (default: current directory)
#   -b, -build          Force rebuild the Docker image before running
#   -s, -shell          Start a shell instead of opencode
#   -h, -help           Show this help message
#

param(
    [Alias("c")]
    [string]$config,
    
    [Alias("d")]
    [string]$data,
    
    [Alias("w")]
    [string]$workdir,
    
    [Alias("b")]
    [switch]$build,
    
    [Alias("s")]
    [switch]$shell,
    
    [Alias("h")]
    [switch]$help,
    
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$OpenCodeArgs
)

# Get the directory where this script is located
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Defaults
$ImageName = "opencode-container:latest"
$WorkDir = if ($workdir) { $workdir } else { $PWD.Path }
$ConfigDir = if ($config) { $config } else { Join-Path $env:USERPROFILE ".config\opencode" }
$DataDir = if ($data) { $data } else { Join-Path $env:USERPROFILE ".local\share\opencode" }
$ContainerHome = "/root"

if ($help) {
    Write-Host @"

opencode-docker.ps1 - Run opencode in an isolated Docker container

Usage:
  opencode-docker.ps1 [OPTIONS] [-- OPENCODE_ARGS...]

Options:
  -c, -config PATH    Use custom config directory
  -d, -data PATH      Use custom data directory
  -w, -workdir PATH   Use custom working directory (default: current directory)
  -b, -build          Force rebuild the Docker image before running
  -s, -shell          Start a shell instead of opencode
  -h, -help           Show this help message

Examples:
  opencode-docker.ps1                           # Run in current directory
  opencode-docker.ps1 -c C:\path\to\config      # Use custom config
  opencode-docker.ps1 -w C:\path\to\project     # Run in specific directory
  opencode-docker.ps1 -s                        # Start shell for debugging
  opencode-docker.ps1 -- --help                 # Pass args to opencode

"@
    exit 0
}

# Validate working directory
if (-not (Test-Path $WorkDir)) {
    Write-Host "[ERROR] Working directory does not exist: $WorkDir" -ForegroundColor Red
    exit 1
}

# Convert to absolute paths
$WorkDir = (Resolve-Path $WorkDir).Path

# Create config directory if it doesn't exist
if (-not (Test-Path $ConfigDir)) {
    Write-Host "[WARN] Config directory does not exist: $ConfigDir" -ForegroundColor Yellow
    Write-Host "[INFO] Creating config directory..." -ForegroundColor Green
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
}
$ConfigDir = (Resolve-Path $ConfigDir).Path

# Create data directory if it doesn't exist
if (-not (Test-Path $DataDir)) {
    Write-Host "[WARN] Data directory does not exist: $DataDir" -ForegroundColor Yellow
    Write-Host "[INFO] Creating data directory..." -ForegroundColor Green
    New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
}
$DataDir = (Resolve-Path $DataDir).Path

# Check if Docker is running
$dockerInfo = docker info 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Docker is not running. Please start Docker and try again." -ForegroundColor Red
    exit 1
}

# Check if image exists or force build
$ImageExists = docker images -q $ImageName 2>$null
$NeedBuild = (-not $ImageExists) -or $build

if ($NeedBuild) {
    Write-Host "[INFO] Building Docker image..." -ForegroundColor Green
    
    $Dockerfile = Join-Path $ScriptDir "Dockerfile"
    if (-not (Test-Path $Dockerfile)) {
        Write-Host "[ERROR] Dockerfile not found at $Dockerfile" -ForegroundColor Red
        exit 1
    }
    
    docker build -t $ImageName $ScriptDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Failed to build Docker image." -ForegroundColor Red
        exit 1
    }
    Write-Host "[INFO] Docker image built successfully." -ForegroundColor Green
}

# Show what we're doing
Write-Host "[INFO] Work directory: $WorkDir" -ForegroundColor Green
Write-Host "[INFO] Config directory: $ConfigDir" -ForegroundColor Green
Write-Host "[INFO] Data directory: $DataDir" -ForegroundColor Green

# Build docker run arguments
$DockerArgs = @(
    "run", "--rm", "-it",
    "-v", "${WorkDir}:/work",
    "-v", "${ConfigDir}:${ContainerHome}/.config/opencode",
    "-v", "${DataDir}:${ContainerHome}/.local/share/opencode"
)

# Mount AGENTS.md if it exists
$AgentsFile = Join-Path $ScriptDir "AGENTS.md"
if (Test-Path $AgentsFile) {
    $DockerArgs += "-v"
    $DockerArgs += "${AgentsFile}:${ContainerHome}/.config/opencode/AGENTS.md:ro"
}

$DockerArgs += @(
    "-w", "/work",
    "-e", "TERM=xterm-256color"
)

# Pass through API keys if set
if ($env:ANTHROPIC_API_KEY) {
    $DockerArgs += "-e"
    $DockerArgs += "ANTHROPIC_API_KEY=$env:ANTHROPIC_API_KEY"
}
if ($env:OPENAI_API_KEY) {
    $DockerArgs += "-e"
    $DockerArgs += "OPENAI_API_KEY=$env:OPENAI_API_KEY"
}

$DockerArgs += $ImageName

if ($shell) {
    Write-Host "[INFO] Starting shell in container..." -ForegroundColor Green
    $DockerArgs += "/bin/bash"
} else {
    $DockerArgs += "opencode"
    if ($OpenCodeArgs) {
        # Filter out the "--" separator if present
        $OpenCodeArgs = $OpenCodeArgs | Where-Object { $_ -ne "--" }
        $DockerArgs += $OpenCodeArgs
    }
}

# Run docker
& docker @DockerArgs
