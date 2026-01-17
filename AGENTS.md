# Container Environment

You are running inside an isolated Docker container. This provides a safe, sandboxed environment for code execution.

## Available Tools

- **Node.js 22** with npm
- **Python 3** with pip
- **Git** for version control
- **ripgrep (rg)** for fast code search
- **fd** for fast file finding
- **jq** for JSON processing
- **curl, wget** for HTTP requests
- **vim, less** for file viewing/editing
- **openssh-client** for SSH operations

## Directory Structure

- `/work` - Your project directory (mounted from host)
- `/root/.config/opencode` - OpenCode configuration

## Constraints

- You have full read/write access to `/work`
- Network access is available
- Changes to `/work` persist on the host filesystem
- All other changes are ephemeral and lost when the container exits
