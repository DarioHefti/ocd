# OpenCode Docker Container

Run [OpenCode](https://opencode.ai) in an isolated Docker container, keeping your host system clean and secure.

## Why Use This?

- **Isolation**: OpenCode only has access to the directory you specify, not your entire system
- **Consistency**: Same environment on macOS and Linux
- **Clean**: No global npm packages polluting your system
- **Portable**: Share your config across machines easily

## Quick Start

```bash
# One-time setup (builds image + adds 'ocd' alias)
./setup.sh

# Open a new terminal (or source your shell config), then:
ocd
```

That's it. Run `ocd` from any project directory to launch OpenCode in a container.

## Installation

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed and running
- macOS or Linux

### Setup

1. Clone or download this repository
2. Run the setup script:

```bash
cd opencode-container
./setup.sh
```

The setup script will:
- Build the Docker image
- Create `~/.config/opencode` if it doesn't exist
- Add the `ocd` alias to your shell (bash/zsh)

## Usage

### Basic Commands

```bash
# Run opencode in current directory
ocd

# Run opencode in a specific directory
ocd -w /path/to/project

# Use a custom config directory
ocd -c /path/to/custom/config

# Force rebuild the Docker image
ocd -b

# Start a shell in the container (for debugging)
ocd -s

# Pass arguments directly to opencode
ocd -- --help

# Show help
ocd -h
```

### Options Reference

| Option | Long Form | Description |
|--------|-----------|-------------|
| `-c` | `--config PATH` | Use custom config directory (overrides `~/.config/opencode`) |
| `-w` | `--workdir PATH` | Use custom working directory (default: current directory) |
| `-b` | `--build` | Force rebuild the Docker image before running |
| `-s` | `--shell` | Start a bash shell instead of opencode |
| `-h` | `--help` | Show help message |

### Examples

```bash
# Work on a project in ~/projects/myapp
ocd -w ~/projects/myapp

# Use work config for work projects
ocd -c ~/.config/opencode-work

# Update the container after a new opencode release
ocd -b

# Debug: check what's installed in the container
ocd -s
```

## Configuration

### API Keys

API keys are read from your config directory (`~/.config/opencode` by default). You can also pass them as environment variables:

```bash
export ANTHROPIC_API_KEY="your-key-here"
ocd
```

### Custom Config Directory

Use the `-c` flag to point to a different config:

```bash
# Use a project-specific config
ocd -c ./my-project/.opencode-config

# Use a work-specific config
ocd -c ~/.config/opencode-work
```

This is useful for:
- Different API keys for work vs personal projects
- Project-specific OpenCode settings
- Testing different configurations

## Tools Included

The container comes with common development tools pre-installed:

| Tool | Description |
|------|-------------|
| Node.js 22 | JavaScript runtime |
| npm | Node package manager |
| git | Version control |
| python3 | Python interpreter |
| pip | Python package manager |
| curl / wget | HTTP clients |
| jq | JSON processor |
| ripgrep (rg) | Fast text search |
| fd | Fast file finder |
| vim | Text editor |
| less | Pager |
| ssh | For git over SSH |

## Architecture Support

The container automatically builds for your system's architecture:
- **arm64**: Apple Silicon (M1/M2/M3 Macs)
- **amd64**: Intel Macs, Linux x86_64

## File Structure

```
opencode-container/
├── Dockerfile           # Container definition
├── docker-compose.yml   # Compose config (alternative to shell script)
├── opencode-docker.sh   # Main launcher script
├── setup.sh             # One-time installation script
└── README.md            # This file
```

## Troubleshooting

### "Docker is not running"

Start Docker Desktop (macOS) or the Docker daemon (Linux):

```bash
# Linux
sudo systemctl start docker

# macOS: Open Docker Desktop app
```

### "Permission denied" when running scripts

Make the scripts executable:

```bash
chmod +x *.sh
```

### Alias not working

Either open a new terminal or source your shell config:

```bash
# For zsh (default on macOS)
source ~/.zshrc

# For bash
source ~/.bashrc
```

### Rebuild after OpenCode update

When a new version of OpenCode is released:

```bash
ocd -b
```

### Container can't access my files

Make sure you're running `ocd` from the directory you want to work in, or use `-w`:

```bash
cd /path/to/project
ocd

# Or
ocd -w /path/to/project
```

## Using with Docker Compose (Alternative)

If you prefer docker-compose over the shell script:

```bash
# Run from the opencode-container directory
OPENCODE_WORK_DIR=/path/to/project docker-compose run --rm opencode

# Or set the env var in your shell
export OPENCODE_WORK_DIR=/path/to/project
docker-compose run --rm opencode
```

## Uninstallation

1. Remove the alias from your shell config (`~/.zshrc` or `~/.bashrc`)
2. Remove the Docker image:

```bash
docker rmi opencode-container:latest
```

3. Delete this directory

## License

MIT
