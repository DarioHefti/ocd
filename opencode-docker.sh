#!/bin/bash
#
# opencode-docker.sh - Run opencode in an isolated Docker container
#
# Usage:
#   opencode-docker.sh [OPTIONS] [-- OPENCODE_ARGS...]
#
# Options:
#   -c, --config PATH    Use custom config directory (overrides ~/.config/opencode)
#   -d, --data PATH      Use custom data directory (overrides ~/.local/share/opencode)
#   -w, --workdir PATH   Use custom working directory (default: current directory)
#   -b, --build          Force rebuild the Docker image before running
#   -s, --shell          Start a shell instead of opencode
#   -h, --help           Show this help message
#
# Examples:
#   opencode-docker.sh                           # Run in current directory
#   opencode-docker.sh -c /path/to/config        # Use custom config
#   opencode-docker.sh -w /path/to/project       # Run in specific directory
#   opencode-docker.sh -s                        # Start shell for debugging
#   opencode-docker.sh -- --help                 # Pass args to opencode
#

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults
WORK_DIR="$(pwd)"
CONFIG_DIR="${HOME}/.config/opencode"
DATA_DIR="${HOME}/.local/share/opencode"
STATE_DIR="${HOME}/.local/state/opencode"
FORCE_BUILD=false
START_SHELL=false
IMAGE_NAME="opencode-container:latest"
OPENCODE_ARGS=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_help() {
    # Extract help text between the first '# Usage:' and the closing '#'
    sed -n '/^# Usage:/,/^[^#]/{ /^#/s/^# \?//p }' "$0"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            if [[ -z "${2:-}" || "$2" == -* ]]; then
                log_error "Option $1 requires a path argument"
                exit 1
            fi
            CONFIG_DIR="$2"
            shift 2
            ;;
        -d|--data)
            if [[ -z "${2:-}" || "$2" == -* ]]; then
                log_error "Option $1 requires a path argument"
                exit 1
            fi
            DATA_DIR="$2"
            shift 2
            ;;
        -w|--workdir)
            if [[ -z "${2:-}" || "$2" == -* ]]; then
                log_error "Option $1 requires a path argument"
                exit 1
            fi
            WORK_DIR="$2"
            shift 2
            ;;
        -b|--build)
            FORCE_BUILD=true
            shift
            ;;
        -s|--shell)
            START_SHELL=true
            shift
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        --)
            shift
            OPENCODE_ARGS=("$@")
            break
            ;;
        *)
            log_error "Unknown option: $1"
            print_help
            exit 1
            ;;
    esac
done

# Validate paths
if [[ ! -d "$WORK_DIR" ]]; then
    log_error "Working directory does not exist: $WORK_DIR"
    exit 1
fi

# Convert to absolute paths
WORK_DIR="$(cd "$WORK_DIR" && pwd)"
if [[ -d "$CONFIG_DIR" ]]; then
    CONFIG_DIR="$(cd "$CONFIG_DIR" && pwd)"
else
    log_warn "Config directory does not exist: $CONFIG_DIR"
    log_info "Creating config directory..."
    mkdir -p "$CONFIG_DIR"
    CONFIG_DIR="$(cd "$CONFIG_DIR" && pwd)"
fi

if [[ -d "$DATA_DIR" ]]; then
    DATA_DIR="$(cd "$DATA_DIR" && pwd)"
else
    log_warn "Data directory does not exist: $DATA_DIR"
    log_info "Creating data directory..."
    mkdir -p "$DATA_DIR"
    DATA_DIR="$(cd "$DATA_DIR" && pwd)"
fi

if [[ -d "$STATE_DIR" ]]; then
    STATE_DIR="$(cd "$STATE_DIR" && pwd)"
else
    log_warn "State directory does not exist: $STATE_DIR"
    log_info "Creating state directory..."
    mkdir -p "$STATE_DIR"
    STATE_DIR="$(cd "$STATE_DIR" && pwd)"
fi

# Copy container AGENTS.md to config directory
# This ensures opencode always knows about the container environment
CONTAINER_AGENTS_MD="$SCRIPT_DIR/AGENTS.md"
if [[ -f "$CONTAINER_AGENTS_MD" ]]; then
    CONFIG_AGENTS_MD="$CONFIG_DIR/AGENTS.md"
    
    # Check if we need to update (file doesn't exist, is empty, or doesn't contain container marker)
    if [[ ! -f "$CONFIG_AGENTS_MD" ]] || [[ ! -s "$CONFIG_AGENTS_MD" ]] || ! grep -q "# Container Environment" "$CONFIG_AGENTS_MD" 2>/dev/null; then
        log_info "Updating AGENTS.md with container environment info..."
        
        # If config AGENTS.md exists and has content (but no container section), append
        if [[ -f "$CONFIG_AGENTS_MD" ]] && [[ -s "$CONFIG_AGENTS_MD" ]]; then
            # Append container info with a separator
            {
                echo ""
                echo "# --- Container Environment (auto-added by opencode-docker.sh) ---"
                echo ""
                cat "$CONTAINER_AGENTS_MD"
            } >> "$CONFIG_AGENTS_MD"
        else
            # Just copy the container AGENTS.md
            cp "$CONTAINER_AGENTS_MD" "$CONFIG_AGENTS_MD"
        fi
    fi
fi

# Check if Docker is running
if ! docker info &>/dev/null; then
    log_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if image exists or force build
IMAGE_EXISTS=$(docker images -q "$IMAGE_NAME" 2>/dev/null)

if [[ -z "$IMAGE_EXISTS" ]] || [[ "$FORCE_BUILD" == "true" ]]; then
    log_info "Building Docker image..."
    
    # Check if we have the Dockerfile
    if [[ ! -f "$SCRIPT_DIR/Dockerfile" ]]; then
        log_error "Dockerfile not found at $SCRIPT_DIR/Dockerfile"
        exit 1
    fi
    
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
    log_info "Docker image built successfully."
fi

# Get host user/group IDs for file ownership (Linux only)
HOST_UID=$(id -u)
HOST_GID=$(id -g)

# Use non-root user on Linux to fix file ownership issues
if [[ "$OSTYPE" == "linux"* ]]; then
    CONTAINER_HOME="/home/opencode"
    RUN_AS_USER=true
    
    # Fix ownership of existing directories if they're owned by root
    if [[ -d "$CONFIG_DIR" ]] && [[ "$(stat -c '%u' "$CONFIG_DIR" 2>/dev/null)" == "0" ]]; then
        log_warn "Config directory is owned by root, fixing ownership..."
        sudo chown -R "$HOST_UID:$HOST_GID" "$CONFIG_DIR" 2>/dev/null || \
            log_error "Could not fix ownership of $CONFIG_DIR - run: sudo chown -R \$(id -u):\$(id -g) $CONFIG_DIR"
    fi
    if [[ -d "$DATA_DIR" ]] && [[ "$(stat -c '%u' "$DATA_DIR" 2>/dev/null)" == "0" ]]; then
        log_warn "Data directory is owned by root, fixing ownership..."
        sudo chown -R "$HOST_UID:$HOST_GID" "$DATA_DIR" 2>/dev/null || \
            log_error "Could not fix ownership of $DATA_DIR - run: sudo chown -R \$(id -u):\$(id -g) $DATA_DIR"
    fi
    if [[ -d "$STATE_DIR" ]] && [[ "$(stat -c '%u' "$STATE_DIR" 2>/dev/null)" == "0" ]]; then
        log_warn "State directory is owned by root, fixing ownership..."
        sudo chown -R "$HOST_UID:$HOST_GID" "$STATE_DIR" 2>/dev/null || \
            log_error "Could not fix ownership of $STATE_DIR - run: sudo chown -R \$(id -u):\$(id -g) $STATE_DIR"
    fi
else
    # On macOS, Docker Desktop handles file ownership automatically
    CONTAINER_HOME="/root"
    RUN_AS_USER=false
fi

# Prepare docker run command
DOCKER_CMD=(
    docker run
    --rm
)

# Handle TTY: use -it if terminal is available, otherwise just -i
if [[ -t 0 && -t 1 ]]; then
    DOCKER_CMD+=(-it)
else
    DOCKER_CMD+=(-i)
fi

DOCKER_CMD+=(
    -v "$WORK_DIR:/work"
    -v "$CONFIG_DIR:$CONTAINER_HOME/.config/opencode"
    -v "$DATA_DIR:$CONTAINER_HOME/.local/share/opencode"
    -v "$STATE_DIR:$CONTAINER_HOME/.local/state/opencode"
    -w /work
    -e "TERM=${TERM:-xterm-256color}"
    -e "HOME=$CONTAINER_HOME"
)

# Run as host user on Linux to fix file ownership
if [[ "$RUN_AS_USER" == "true" ]]; then
    DOCKER_CMD+=(--user "$HOST_UID:$HOST_GID")
fi

# Pass through API keys if they exist in the environment
[[ -n "$ANTHROPIC_API_KEY" ]] && DOCKER_CMD+=(-e "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY")
[[ -n "$OPENAI_API_KEY" ]] && DOCKER_CMD+=(-e "OPENAI_API_KEY=$OPENAI_API_KEY")

# Add image name
DOCKER_CMD+=("$IMAGE_NAME")

# Add command
if [[ "$START_SHELL" == "true" ]]; then
    log_info "Starting shell in container..."
    DOCKER_CMD+=(/bin/bash)
else
    DOCKER_CMD+=(opencode)
    if [[ ${#OPENCODE_ARGS[@]} -gt 0 ]]; then
        DOCKER_CMD+=("${OPENCODE_ARGS[@]}")
    fi
fi

# Show what we're doing
log_info "Work directory: $WORK_DIR"
log_info "Config directory: $CONFIG_DIR"
log_info "Data directory: $DATA_DIR"
log_info "State directory: $STATE_DIR"

# Run the container
exec "${DOCKER_CMD[@]}"
