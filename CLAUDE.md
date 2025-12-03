# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

YACCS (Yet Another Claude Code Switcher) is a bash-based CLI tool that manages multiple LLM provider configurations for Claude Code. It allows users to seamlessly switch between different providers (OpenRouter, GLM, Chutes, etc.) without manually managing environment variables.

## Core Architecture

### Configuration System

**Directory Structure:**
```
~/.yaccs/
├── providers/          # Provider configuration files
│   ├── provider1.sh
│   └── provider2.sh
└── active             # Tracks currently active provider
```

Each provider configuration file (`~/.yaccs/providers/{name}.sh`) is a shell script that exports:
- `ANTHROPIC_AUTH_TOKEN` - API authentication key
- `ANTHROPIC_BASE_URL` - Provider's API endpoint
- `ANTHROPIC_MODEL` - Main model identifier
- `ANTHROPIC_DEFAULT_HAIKU_MODEL` - Fast tier model
- `ANTHROPIC_DEFAULT_SONNET_MODEL` - Balanced tier model
- `ANTHROPIC_DEFAULT_OPUS_MODEL` - Powerful tier model
- `CLAUDE_CODE_SUBAGENT_MODEL` - Subagent model
- `ANTHROPIC_SMALL_FAST_MODEL` - Small/fast model
- `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` - Traffic optimization flag

### Command Router Pattern

The main script (`yaccs.sh`) uses a command router pattern where:
1. All commands go through `main()` function
2. Commands are dispatched via case statement to specialized `cmd_*` functions
3. Unknown commands are treated as provider names and routed to `cmd_switch_provider()`

### State Management

- Active provider is tracked in `~/.yaccs/active` (simple text file with provider name)
- Provider switching involves: unset all env vars → source provider config → save active state → exec claude
- Reset/default clears all ANTHROPIC_* variables and removes active tracking

## Key Implementation Details

### Environment Variable Handling

Before switching providers or resetting to default, `unset_anthropic_vars()` function explicitly unsets all ANTHROPIC_* and CLAUDE_CODE_* variables to ensure clean slate. This prevents variable leakage between providers.

### Security Considerations

- Provider config files are created with `chmod 600` (read/write owner only)
- API keys stored in plaintext within these restricted files
- Status command redacts API keys when displaying environment variables using sed substitution

### Interactive Input Handling

Commands that require user input (configure, remove) handle both interactive TTY and non-interactive contexts using conditional input redirection: `</dev/tty` when TTY is available, standard input otherwise.

### Provider Configuration Flow

1. Check if provider exists → offer to keep existing values
2. Prompt for Base URL, API Key, Main Model ID
3. Optionally customize per-tier models (haiku/sonnet/opus/subagent/small-fast)
4. Show preview and confirm before writing
5. Write config file with heredoc template
6. Set restrictive permissions

## Development Commands

### Testing the Tool

```bash
# Direct execution (from repo)
./yaccs.sh help

# Test configuration
./yaccs.sh configure test-provider

# Test provider listing
./yaccs.sh list
```

### Installation

```bash
# Run installer (copies to ~/.local/bin/yaccs)
bash install.sh

# Manual installation
cp yaccs.sh ~/.local/bin/yaccs
chmod +x ~/.local/bin/yaccs
```

### Making Changes

After modifying `yaccs.sh`:
1. Test changes by running script directly: `./yaccs.sh <command>`
2. Reinstall using installer: `bash install.sh`
3. Verify installation: `yaccs help`

## Common Usage Patterns

### Provider Switching Workflow
```bash
yaccs configure provider1      # Interactive setup
yaccs provider1               # Switch and launch Claude Code
# ... work with Claude Code ...
yaccs default                 # Reset to default Claude subscription
```

### Multi-Provider Setup
```bash
yaccs configure openrouter    # Configure first provider
yaccs configure glm           # Configure second provider
yaccs list                    # View all providers
yaccs openrouter             # Switch to openrouter
```

## Code Conventions

- Use `set -euo pipefail` for strict error handling
- All user-facing output goes through `log_*` utility functions
- Use heredocs for multi-line file generation
- Explicitly handle TTY vs non-TTY input contexts
- Provider config files always end with `.sh` extension
- Use `exec claude` to replace current process (not spawn subprocess)

## Important Notes for Modifications

- The `exec claude` call in `cmd_switch_provider()` and `cmd_default()` replaces the current process - this is intentional to properly propagate environment variables to Claude Code
- When adding new environment variables, update both `unset_anthropic_vars()` function and the provider config template in `cmd_configure()`
- Provider config files use a two-step heredoc: first writes comment block (with literal single quotes), then appends variable exports (with variable expansion)
- The active provider tracking file is intentionally simple (just provider name) for easy shell scripting and debugging
