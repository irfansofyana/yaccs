# YACCS - Yet Another Claude Code Switcher

A CLI tool to seamlessly manage and switch between multiple Claude Code LLM provider configurations. Use different providers for different projects or needs without manual environment variable juggling.

```bash
__  _____   _________________
\ \/ /   | / ____/ ____/ ___/
 \  / /| |/ /   / /    \__ \
 / / ___ / /___/ /___ ___/ /
/_/_/  |_\____/\____//____/
Yet Another Claude Code Switcher
by irfansofyana


USAGE:
  yaccs <command> [options]

COMMANDS:
  configure <provider>    Configure a new or existing provider
                         Prompts for: Base URL, API Key, Model ID(s)

  modify <provider>       Modify an existing provider configuration
                         Interactive menu to update specific fields
                         Option 9: Manage custom environment variables

  use <provider>          Set the default provider
                         When 'yaccs' is run with no arguments, it will use this provider

  <provider>             Switch to a provider and run Claude Code
                         All arguments after provider name are passed to claude
                         Example: yaccs glm -r --model opus

  list                   List all configured providers
                         Shows active provider with [*], default with [D]

  status                 Show currently active provider
                         Displays both standard and custom environment variables

  remove <provider>      Remove a configured provider

  help                   Show this help message
```

## Features

- Multi-Provider Support - Configure and switch between multiple LLM providers
- Fast Switching - One command to switch providers and launch Claude Code
- Smart Model Defaults - Use a single model for all tiers, or customize per tier
- Provider Management - List, view status, and remove providers
- Easy Configuration - Interactive prompts for setting up new providers
- Secure - API keys stored with restrictive file permissions (chmod 600)
- Custom Environment Variables - Add provider-specific environment variables

## Custom Environment Variables

YACCS supports custom environment variables for each provider. These can be configured during initial setup or added later through the modify command.

Common use cases:
- `DISABLE_PROMPT_CACHING=1` - For providers without prompt caching support (e.g., Qwen)
- `ENABLE_DEBUG=true` - For debugging/testing configurations
- `CUSTOM_TIMEOUT=30` - For performance tuning

You can add, modify, or remove custom variables via `yaccs configure` or `yaccs modify`.

Reference: [Environment Variables](https://code.claude.com/docs/en/settings#environment-variables)

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
- **Per-tier Models** (optional) - Different models for haiku (fast), sonnet (balanced), opus (powerful), subagent, small-fast
- **Disable Non-Essential Traffic** (optional) - Reduce Claude Code background API calls
- **Custom Environment Variables** (optional) - Add provider-specific environment variables

**Example:**

```bash
$ yaccs configure openrouter
Enter Base URL: https://openrouter.ai/api/v1
Enter API Key: ••••••••••••••••
Enter Main Model ID: anthropic/claude-3-sonnet-20240229
Customize models per tier? (y/n): n
Disable Non-Essential Traffic? (y/n): n
Add custom environment variables? (y/n): n
✓ Provider 'openrouter' configured successfully
```

### Modify a Provider

```bash
yaccs modify <provider-name>
```

Opens an interactive menu with options to update provider settings:

- **Options 0-8** - Modify various provider settings (Base URL, API Key, models per tier)
- **Option T** - Toggle Disable Non-Essential Traffic setting
- **Option 9** - Manage Custom Environment Variables (add, edit, delete)
- **Option 0** - Rename provider

### Set Default Provider

```bash
yaccs use <provider-name>
```

Sets the default provider. When `yaccs` is run with no arguments, it will use this provider. Useful for setting up a primary provider you use most frequently.

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

### Passing Arguments to Claude Code

YACCS seamlessly passes any arguments after the provider name directly to Claude Code. This means you can use all Claude Code flags and options:

```bash
# Resume your previous Claude session
yaccs chutes -r
yaccs openrouter --resume

# Use a specific model tier
yaccs glm -m opus
yaccs chutes --model sonnet

# Get help for Claude Code
yaccs chutes --help

# Combine multiple arguments
yaccs openrouter -r -m opus
yaccs glm --resume --model sonnet
```

**All standard Claude Code flags and options are supported**, including:
- `-r, --resume` - Resume your previous session
- `-m, --model <tier>` - Specify model tier (haiku/sonnet/opus/subagent)
- `--help` - Show Claude Code help
- Any other Claude Code arguments

The implementation uses `exec claude "$@"` which means arguments are passed through transparently.

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

2. **Provider configs are simple shell scripts** - You can manually edit them if needed:

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
yaccs glm

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
# Remove provider configurations to clear all provider vars
yaccs remove openrouter
yaccs remove glm
yaccs remove localllm

# Verify it's clean
yaccs status
# Output: No provider active
```

## Security Considerations

⚠️ **API Keys are stored in plaintext** in `~/.yaccs/providers/` files. This is intentional for usability but comes with risks:

- Files are created with `chmod 600` (readable only by you)
- Don't commit `~/.yaccs/` to version control
- Don't share these files with others
- Consider removing provider configs before sharing your computer
- Use `yaccs remove <provider>` to remove providers and clear environment variables before multi-user access

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

## Contributing

Contributions welcome! Please submit issues and pull requests.
