#!/bin/bash
#
# setup.sh - One-time setup for opencode-docker
#
# This script will:
#   1. Build the Docker image
#   2. Create the opencode config directory if it doesn't exist
#   3. Add an alias to your shell config (bash/zsh)
#
# After running this script, you can use 'ocd' from anywhere to launch opencode in Docker.
#

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

IMAGE_NAME="opencode-container:latest"
ALIAS_NAME="ocd"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
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

# Detect shell and add alias
log_step "Setting up shell alias..."

LAUNCHER_PATH="$SCRIPT_DIR/opencode-docker.sh"
# Use a function instead of alias to handle paths with spaces correctly
FUNC_LINE="$ALIAS_NAME() { \"$LAUNCHER_PATH\" \"\$@\"; }"

# Function to add shell function to a config file
add_func_to_file() {
    local file="$1"
    local shell_name="$2"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    # Check if function or old alias already exists
    if grep -qE "^$ALIAS_NAME\(\)|^alias $ALIAS_NAME=" "$file" 2>/dev/null; then
        log_warn "Function/alias '$ALIAS_NAME' already exists in $file"
        # Remove old alias-style definition if present
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "/^alias $ALIAS_NAME=/d" "$file"
            sed -i '' "/^$ALIAS_NAME()/d" "$file"
        else
            sed -i "/^alias $ALIAS_NAME=/d" "$file"
            sed -i "/^$ALIAS_NAME()/d" "$file"
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
echo "  ${GREEN}$ALIAS_NAME${NC}                    - Run opencode in current directory"
echo "  ${GREEN}$ALIAS_NAME -c /path/to/config${NC} - Use custom config directory"
echo "  ${GREEN}$ALIAS_NAME -w /path/to/project${NC} - Run in specific directory"
echo "  ${GREEN}$ALIAS_NAME -s${NC}                 - Start a shell in the container"
echo "  ${GREEN}$ALIAS_NAME -b${NC}                 - Force rebuild the image"
echo "  ${GREEN}$ALIAS_NAME -h${NC}                 - Show all options"
echo ""
echo "To use the alias now, either:"
echo "  1. Open a new terminal, or"
echo "  2. Run: ${YELLOW}source ~/.zshrc${NC} (or ~/.bashrc)"
echo ""
