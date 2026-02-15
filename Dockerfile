FROM node:22-slim

# Install common dev tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    jq \
    python3 \
    python3-pip \
    python3-venv \
    openssh-client \
    ca-certificates \
    gnupg \
    less \
    vim \
    ripgrep \
    fd-find \
    && rm -rf /var/lib/apt/lists/*

# Create symlinks for fd (installed as fdfind on Debian)
RUN ln -sf /usr/bin/fdfind /usr/bin/fd

# Install opencode globally
RUN npm i -g opencode-ai

# Create opencode user home directory with proper structure for non-root execution
# This allows running with --user flag while still having a writable home directory
RUN mkdir -p /home/opencode/.config/opencode \
    /home/opencode/.local/share/opencode \
    /home/opencode/.local/state \
    && chmod -R 777 /home/opencode

# Set up working directory
WORKDIR /work

# Default command
CMD ["opencode"]
