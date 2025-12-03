# YACCS - Yet Another Claude Code Switcher

A CLI tool to seamlessly manage and switch between multiple Claude Code LLM provider configurations. Use different providers for different projects or needs without manual environment variable juggling.

## Features

- ✨ **Multi-Provider Support** - Configure and switch between multiple LLM providers
- ⚡ **Fast Switching** - One command to switch providers and launch Claude Code
- 🎯 **Smart Model Defaults** - Use a single model for all tiers, or customize per tier
- 📊 **Provider Management** - List, view status, and remove providers
- 🔧 **Easy Configuration** - Interactive prompts for setting up new providers
- 🛡️ **Secure** - API keys stored with restrictive file permissions (chmod 600)

## Installation

### Quick Start

```bash
bash /path/to/yaccs/install.sh
```

The installer will:

- Create the configuration directory at `~/.yaccs/`
- Install `yaccs` to `~/.local/bin/` (or `/usr/local/bin/`)
- Add `~/.local/bin/` to your PATH if needed

**Note:** If `~/.local/bin/` isn't already in your PATH, the installer will guide you through adding it.

### Manual Installation

1. Clone or download the repository
2. Copy `yaccs.sh` to `~/.local/bin/yaccs` and make it executable:

```bash
cp yaccs.sh ~/.local/bin/yaccs
chmod +x ~/.local/bin/yaccs
```

3. Ensure `~/.local/bin/` is in your PATH:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc  # or ~/.zshrc
```

## Usage

### Configure a Provider

```bash
yaccs configure <provider-name>
```

Interactive prompts will ask for:

- **Base URL** - The LLM provider's API endpoint (e.g., `https://api.openrouter.ai/api/v1`)
- **API Key** - Your authentication token for the provider
- **Model ID** - The primary model to use (e.g., `anthropic/claude-3-sonnet-20240229`)
- **Per-tier Models** (optional) - Different models for haiku (fast), sonnet (balanced), opus (powerful), subagent

**Example:**

```bash
$ yaccs configure openrouter
Enter Base URL: https://openrouter.ai/api/v1
Enter API Key: ••••••••••••••••
Enter Main Model ID: anthropic/claude-3-sonnet-20240229
Customize models per tier? (y/n): n
✓ Provider 'openrouter' configured successfully
```

### Switch to a Provider

```bash
yaccs <provider-name>
```

Launches Claude Code with the specified provider's configuration.

**Examples:**

```bash
yaccs openrouter                    # Use OpenRouter provider
yaccs glm --help                    # Use GLM provider and pass --help to claude
yaccs chutes auth:show-status       # Use Chutes provider with custom args
```

### List All Providers

```bash
yaccs list
```

Shows all configured providers with their base URLs and models. Active provider marked with `[*]`.

**Output:**

```text
Configured providers:
  [*] openrouter   https://openrouter.ai/api/v1 (model: anthropic/claude-3-sonnet-20240229)
  [ ] glm          https://open.bigmodel.cn/api/anthropic (model: GLM-4.6)
  [ ] chutes       https://claude.chutes.ai (model: Qwen/Qwen3-Coder-480B)
```

### Check Status

```bash
yaccs status
```

Shows the currently active provider and its environment variables (API key redacted).

**Output:**

```text
Active provider: openrouter
Config file: /Users/username/.yaccs/providers/openrouter.sh

Environment variables:
  ANTHROPIC_AUTH_TOKEN=***REDACTED***
  ANTHROPIC_BASE_URL=https://openrouter.ai/api/v1
  ANTHROPIC_MODEL=anthropic/claude-3-sonnet-20240229
  ...
```

### Reset to Default Claude

```bash
yaccs default
```

or

```bash
yaccs reset
```

Unsets all provider environment variables and launches Claude Code with your default subscription.

### Remove a Provider

```bash
yaccs remove <provider-name>
```

Deletes a configured provider. Will prompt for confirmation before deletion.

### View Help

```bash
yaccs help
```

Shows complete command reference.

## Configuration Structure

YACCS stores configurations in `~/.yaccs/`:

```text
~/.yaccs/
├── providers/
│   ├── openrouter.sh
│   ├── glm.sh
│   └── chutes.sh
└── active                    # Tracks currently active provider
```

Each provider file is a shell script that exports environment variables:

```bash
export ANTHROPIC_AUTH_TOKEN="..."
export ANTHROPIC_BASE_URL="..."
export ANTHROPIC_MODEL="..."
export ANTHROPIC_DEFAULT_HAIKU_MODEL="..."
export ANTHROPIC_DEFAULT_SONNET_MODEL="..."
export ANTHROPIC_DEFAULT_OPUS_MODEL="..."
export CLAUDE_CODE_SUBAGENT_MODEL="..."
export ANTHROPIC_SMALL_FAST_MODEL="..."
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
```

Files are created with restrictive permissions (`chmod 600`) to protect sensitive API keys.

## How It Works

1. **When you run `yaccs <provider>`:**
   - Unsets all existing ANTHROPIC_* environment variables (clean slate)
   - Sources the provider's configuration file
   - Records the active provider
   - Passes remaining arguments to the `claude` command

2. **When you run `yaccs default`:**
   - Unsets all provider environment variables
   - Clears the active provider tracking
   - Launches Claude Code with default behavior

3. **Provider configs are simple shell scripts** - You can manually edit them if needed:

```bash
nano ~/.yaccs/providers/myprovidername.sh
```

## Examples

### Using Multiple Providers

```bash
# Configure three providers
yaccs configure openrouter
yaccs configure glm
yaccs configure localllm

# Use OpenRouter for a project
yaccs openrouter
# Claude Code launches with OpenRouter config...

# Switch to GLM without leaving Claude Code
yaccs default
# Back to default Claude subscription

# Use local LLM
yaccs localllm
```

### Custom Model Tiers

When configuring, you can set different models for different tiers:

```bash
$ yaccs configure mixed-models
Enter Base URL: https://api.example.com
Enter API Key: sk_...
Enter Main Model ID: claude-3-sonnet
Customize models per tier (haiku/sonnet/opus/subagent)? (y/n): y
Haiku model (fast): claude-3-haiku
Sonnet model (balanced): claude-3-sonnet
Opus model (powerful): claude-3-opus
Subagent model: claude-3-sonnet
Small/Fast model: claude-3-haiku
```

### Sharing Your System

Before sharing your system or checking it into version control:

```bash
# Reset to default and unset all provider vars
yaccs default

# Verify it's clean
yaccs status
# Output: No provider active (using default Claude Code)
```

## Security Considerations

⚠️ **API Keys are stored in plaintext** in `~/.yaccs/providers/` files. This is intentional for usability but comes with risks:

- Files are created with `chmod 600` (readable only by you)
- Don't commit `~/.yaccs/` to version control
- Don't share these files with others
- Consider removing provider configs before sharing your computer
- Use `yaccs default` to clear environment variables before multi-user access

## Troubleshooting

### `yaccs` command not found

Make sure `~/.local/bin/` is in your PATH:

```bash
# Check if it's in PATH
echo $PATH | grep -q "$HOME/.local/bin" && echo "OK" || echo "NOT IN PATH"

# Add to PATH (choose one)
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc  # Bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc   # Zsh

# Reload shell config
source ~/.bashrc  # or ~/.zshrc
```

### Provider not found

```bash
# List all configured providers
yaccs list

# Configure the provider
yaccs configure <provider-name>
```

### Environment variables not being set

```bash
# Check the config file exists and has correct content
cat ~/.yaccs/providers/<provider-name>.sh

# Verify permissions (should be 600)
ls -la ~/.yaccs/providers/<provider-name>.sh
```

## Development

To modify YACCS:

1. Edit `yaccs.sh` in the repository
2. Test your changes
3. Run the installer to update: `bash install.sh`

## License

[Your License Here]

## Contributing

Contributions welcome! Please submit issues and pull requests.

## Support

- Report issues: [GitHub Issues]
- Discuss: [GitHub Discussions]
