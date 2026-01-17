#!/bin/bash
#
# setup.sh - One-time setup for opencode-docker
#
# This script will:
#   1. Build the Docker image
#   2. Create the opencode config directory if it doesn't exist
#   3. Add a function to your shell config (bash/zsh)
#
# After running this script, you can use 'ocd' from anywhere to launch opencode in Docker.
#

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output (only if terminal supports it)
if [[ -t 1 ]]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    BLUE=$'\033[0;34m'
    NC=$'\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

IMAGE_NAME="opencode-container:latest"
ALIAS_NAME="ocd"

log_info() {
    printf '%s[INFO]%s %s\n' "$GREEN" "$NC" "$1"
}

log_warn() {
    printf '%s[WARN]%s %s\n' "$YELLOW" "$NC" "$1"
}

log_error() {
    printf '%s[ERROR]%s %s\n' "$RED" "$NC" "$1"
}

log_step() {
    printf '%s[STEP]%s %s\n' "$BLUE" "$NC" "$1"
}

echo ""
echo "========================================"
echo "  OpenCode Docker Setup"
echo "========================================"
echo ""

# Check if Docker is installed and running
log_step "Checking Docker..."
if ! command -v docker &>/dev/null; then
    log_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! docker info &>/dev/null; then
    log_error "Docker is not running. Please start Docker and try again."
    exit 1
fi
log_info "Docker is available."

# Build the Docker image
log_step "Building Docker image (this may take a few minutes)..."
docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
log_info "Docker image built successfully."

# Create config directory if needed
log_step "Checking config directory..."
CONFIG_DIR="${HOME}/.config/opencode"
if [[ ! -d "$CONFIG_DIR" ]]; then
    log_info "Creating config directory at $CONFIG_DIR"
    mkdir -p "$CONFIG_DIR"
else
    log_info "Config directory already exists at $CONFIG_DIR"
fi

# Make the launcher script executable
log_step "Making scripts executable..."
if [[ -f "$SCRIPT_DIR/opencode-docker.sh" ]]; then
    chmod +x "$SCRIPT_DIR/opencode-docker.sh"
    log_info "Scripts are executable."
else
    log_error "opencode-docker.sh not found at $SCRIPT_DIR"
    exit 1
fi

# Detect shell and set up function
log_step "Setting up shell function..."

LAUNCHER_PATH="$SCRIPT_DIR/opencode-docker.sh"
# Use a function instead of alias to handle paths with spaces correctly
FUNC_LINE="$ALIAS_NAME() { \"$LAUNCHER_PATH\" \"\$@\"; }"

# Check if function already exists and points to the correct path
check_func_exists() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    # Check if function exists and points to current launcher path
    if grep -q "^$ALIAS_NAME() { \"$LAUNCHER_PATH\"" "$file" 2>/dev/null; then
        return 0
    fi
    return 1
}

# Function to add shell function to a config file
add_func_to_file() {
    local file="$1"
    local shell_name="$2"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    # Check if function already exists with correct path
    if check_func_exists "$file"; then
        log_info "Function '$ALIAS_NAME' already configured correctly in $file"
        return 0
    fi
    
    # Check if function or old alias exists (needs update)
    if grep -qE "^$ALIAS_NAME\(\)|^alias $ALIAS_NAME=" "$file" 2>/dev/null; then
        log_warn "Updating existing function/alias '$ALIAS_NAME' in $file"
        # Remove old definitions
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "/^alias $ALIAS_NAME=/d" "$file"
            sed -i '' "/^$ALIAS_NAME() {/d" "$file"
            sed -i '' "/^# OpenCode Docker/d" "$file"
        else
            sed -i "/^alias $ALIAS_NAME=/d" "$file"
            sed -i "/^$ALIAS_NAME() {/d" "$file"
            sed -i "/^# OpenCode Docker/d" "$file"
        fi
    fi
    
    # Add the function
    {
        echo ""
        echo "# OpenCode Docker function"
        echo "$FUNC_LINE"
    } >> "$file"
    
    log_info "Added function to $file"
    return 0
}

FUNC_ADDED=false
ALREADY_CONFIGURED=false

# Check if already fully configured
if check_func_exists "$HOME/.zshrc" || check_func_exists "$HOME/.bashrc" || check_func_exists "$HOME/.bash_profile"; then
    ALREADY_CONFIGURED=true
fi

# Check for zsh (common on macOS)
if [[ -f "$HOME/.zshrc" ]]; then
    add_func_to_file "$HOME/.zshrc" "zsh" && FUNC_ADDED=true
fi

# Check for bash
if [[ -f "$HOME/.bashrc" ]]; then
    add_func_to_file "$HOME/.bashrc" "bash" && FUNC_ADDED=true
elif [[ -f "$HOME/.bash_profile" ]]; then
    add_func_to_file "$HOME/.bash_profile" "bash" && FUNC_ADDED=true
fi

if [[ "$FUNC_ADDED" == "false" ]]; then
    log_warn "Could not find shell config file. Add this function manually:"
    echo ""
    echo "    $FUNC_LINE"
    echo ""
fi

echo ""
echo "========================================"
echo "  Setup Complete!"
echo "========================================"
echo ""
echo "Usage:"
echo ""
printf '  %s%s%s                    - Run opencode in current directory\n' "$GREEN" "$ALIAS_NAME" "$NC"
printf '  %s%s -c /path/to/config%s - Use custom config directory\n' "$GREEN" "$ALIAS_NAME" "$NC"
printf '  %s%s -w /path/to/project%s - Run in specific directory\n' "$GREEN" "$ALIAS_NAME" "$NC"
printf '  %s%s -s%s                 - Start a shell in the container\n' "$GREEN" "$ALIAS_NAME" "$NC"
printf '  %s%s -b%s                 - Force rebuild the image\n' "$GREEN" "$ALIAS_NAME" "$NC"
printf '  %s%s -h%s                 - Show all options\n' "$GREEN" "$ALIAS_NAME" "$NC"
echo ""

if [[ "$ALREADY_CONFIGURED" == "true" ]]; then
    log_info "Shell function was already configured. Image has been rebuilt."
else
    echo "To use the function now, either:"
    echo "  1. Open a new terminal, or"
    printf '  2. Run: %ssource ~/.zshrc%s (or ~/.bashrc)\n' "$YELLOW" "$NC"
    echo ""
fi
