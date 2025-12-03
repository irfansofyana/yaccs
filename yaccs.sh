#!/bin/bash

################################################################################
# YACCS - Yet Another Claude Code Switcher
# Manage multiple Claude Code provider configurations
################################################################################

set -euo pipefail

# ========================
#      Define Constants
# ========================

SCRIPT_NAME="yaccs"
YACCS_DIR="${HOME}/.yaccs"
PROVIDERS_DIR="${YACCS_DIR}/providers"
ACTIVE_FILE="${YACCS_DIR}/active"

# ========================
#      Utility Functions
# ========================

log_info() {
    echo "[INFO] $*"
}

log_success() {
    echo "[ OK ] $*"
}

log_error() {
    echo "[ERR ] $*" >&2
}

ensure_dirs_exist() {
    if [ ! -d "$YACCS_DIR" ]; then
        mkdir -p "$YACCS_DIR" || {
            log_error "Failed to create directory: $YACCS_DIR"
            exit 1
        }
    fi
    if [ ! -d "$PROVIDERS_DIR" ]; then
        mkdir -p "$PROVIDERS_DIR" || {
            log_error "Failed to create directory: $PROVIDERS_DIR"
            exit 1
        }
    fi
}

# Unset all ANTHROPIC_* environment variables
unset_anthropic_vars() {
    unset ANTHROPIC_AUTH_TOKEN 2>/dev/null || true
    unset ANTHROPIC_BASE_URL 2>/dev/null || true
    unset ANTHROPIC_MODEL 2>/dev/null || true
    unset ANTHROPIC_DEFAULT_HAIKU_MODEL 2>/dev/null || true
    unset ANTHROPIC_DEFAULT_SONNET_MODEL 2>/dev/null || true
    unset ANTHROPIC_DEFAULT_OPUS_MODEL 2>/dev/null || true
    unset CLAUDE_CODE_SUBAGENT_MODEL 2>/dev/null || true
    unset ANTHROPIC_SMALL_FAST_MODEL 2>/dev/null || true
    unset CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC 2>/dev/null || true
}

# ========================
#      Configure Command
# ========================

cmd_configure() {
    local provider_name="${1:-}"

    if [ -z "$provider_name" ]; then
        log_error "Usage: $SCRIPT_NAME configure <provider>"
        exit 1
    fi

    ensure_dirs_exist

    local config_file="${PROVIDERS_DIR}/${provider_name}.sh"
    local provider_exists=false
    local keep_existing=false

    # Check if provider already exists
    if [ -f "$config_file" ]; then
        provider_exists=true
        log_info "Found existing configuration for '$provider_name'"
        if [ -t 0 ]; then
            read -p "Keep existing values? (y/n): " keep_input </dev/tty
        else
            read -p "Keep existing values? (y/n): " keep_input
        fi
        if [[ "$keep_input" =~ ^[Yy]$ ]]; then
            keep_existing=true
        fi
    fi

    # Prompt for Base URL
    local base_url=""
    if [ "$keep_existing" = true ]; then
        base_url=$(grep "^export ANTHROPIC_BASE_URL=" "$config_file" | cut -d'=' -f2- | tr -d '"')
        echo "Base URL (current: $base_url): "
        if [ -t 0 ]; then
            read -p "> " base_url_input </dev/tty
        else
            read -p "> " base_url_input
        fi
        [ -n "$base_url_input" ] && base_url="$base_url_input"
    else
        echo "Enter Base URL (e.g., https://api.example.com):"
        if [ -t 0 ]; then
            read -p "> " base_url </dev/tty
        else
            read -p "> " base_url
        fi
    fi

    if [ -z "$base_url" ]; then
        log_error "Base URL cannot be empty"
        exit 1
    fi

    # Prompt for API Key
    local api_key=""
    if [ "$keep_existing" = true ]; then
        echo "Enter API Key (leave blank to keep existing):"
        if [ -t 0 ]; then
            read -s -p "> " api_key_input </dev/tty
        else
            read -p "> " api_key_input
        fi
        echo
        if [ -n "$api_key_input" ]; then
            api_key="$api_key_input"
        else
            api_key=$(grep "^export ANTHROPIC_AUTH_TOKEN=" "$config_file" | cut -d'=' -f2- | tr -d '"')
        fi
    else
        echo "Enter API Key:"
        if [ -t 0 ]; then
            read -s -p "> " api_key </dev/tty
        else
            read -p "> " api_key
        fi
        echo
    fi

    if [ -z "$api_key" ]; then
        log_error "API Key cannot be empty"
        exit 1
    fi

    # Prompt for Main Model ID
    local model_id=""
    if [ "$keep_existing" = true ]; then
        model_id=$(grep "^export ANTHROPIC_MODEL=" "$config_file" | cut -d'=' -f2- | tr -d '"')
        echo "Main Model ID (current: $model_id): "
        if [ -t 0 ]; then
            read -p "> " model_input </dev/tty
        else
            read -p "> " model_input
        fi
        [ -n "$model_input" ] && model_id="$model_input"
    else
        echo "Enter Main Model ID (e.g., gpt-4-turbo):"
        if [ -t 0 ]; then
            read -p "> " model_id </dev/tty
        else
            read -p "> " model_id
        fi
    fi

    if [ -z "$model_id" ]; then
        log_error "Model ID cannot be empty"
        exit 1
    fi

    # Ask about per-tier customization
    local haiku_model="$model_id"
    local sonnet_model="$model_id"
    local opus_model="$model_id"
    local subagent_model="$model_id"
    local small_fast_model="$model_id"

    echo
    if [ -t 0 ]; then
        read -p "Customize models per tier (haiku/sonnet/opus/subagent)? (y/n) [default: n]: " customize_tiers </dev/tty
    else
        read -p "Customize models per tier (haiku/sonnet/opus/subagent)? (y/n) [default: n]: " customize_tiers
    fi

    if [[ "$customize_tiers" =~ ^[Yy]$ ]]; then
        if [ -t 0 ]; then
            read -p "Haiku model (fast) [default: $model_id]: " haiku_input </dev/tty
        else
            read -p "Haiku model (fast) [default: $model_id]: " haiku_input
        fi
        [ -n "$haiku_input" ] && haiku_model="$haiku_input"

        if [ -t 0 ]; then
            read -p "Sonnet model (balanced) [default: $model_id]: " sonnet_input </dev/tty
        else
            read -p "Sonnet model (balanced) [default: $model_id]: " sonnet_input
        fi
        [ -n "$sonnet_input" ] && sonnet_model="$sonnet_input"

        if [ -t 0 ]; then
            read -p "Opus model (powerful) [default: $model_id]: " opus_input </dev/tty
        else
            read -p "Opus model (powerful) [default: $model_id]: " opus_input
        fi
        [ -n "$opus_input" ] && opus_model="$opus_input"

        if [ -t 0 ]; then
            read -p "Subagent model [default: $model_id]: " subagent_input </dev/tty
        else
            read -p "Subagent model [default: $model_id]: " subagent_input
        fi
        [ -n "$subagent_input" ] && subagent_model="$subagent_input"

        if [ -t 0 ]; then
            read -p "Small/Fast model [default: $model_id]: " smallfast_input </dev/tty
        else
            read -p "Small/Fast model [default: $model_id]: " smallfast_input
        fi
        [ -n "$smallfast_input" ] && small_fast_model="$smallfast_input"
    fi

    # Show preview
    echo
    log_info "Configuration preview:"
    echo "  Base URL: $base_url"
    echo "  API Key: ${api_key:0:10}...${api_key: -10}"
    echo "  Main Model: $model_id"
    echo "  Haiku Model: $haiku_model"
    echo "  Sonnet Model: $sonnet_model"
    echo "  Opus Model: $opus_model"
    echo "  Subagent Model: $subagent_model"
    echo "  Small/Fast Model: $small_fast_model"
    echo

    if [ -t 0 ]; then
        read -p "Save configuration? (y/n): " confirm </dev/tty
    else
        read -p "Save configuration? (y/n): " confirm
    fi
    if ! [[ "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Configuration cancelled"
        exit 0
    fi

    # Write configuration file
    cat > "$config_file" << 'EOFCONFIG'
#!/bin/bash
# YACCS Provider Configuration
# Generated automatically - do not edit manually unless you know what you're doing

EOFCONFIG

    cat >> "$config_file" << EOF
export ANTHROPIC_AUTH_TOKEN="${api_key}"
export ANTHROPIC_BASE_URL="${base_url}"
export ANTHROPIC_MODEL="${model_id}"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="${haiku_model}"
export ANTHROPIC_DEFAULT_SONNET_MODEL="${sonnet_model}"
export ANTHROPIC_DEFAULT_OPUS_MODEL="${opus_model}"
export CLAUDE_CODE_SUBAGENT_MODEL="${subagent_model}"
export ANTHROPIC_SMALL_FAST_MODEL="${small_fast_model}"
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
EOF

    chmod 600 "$config_file"
    log_success "Provider '$provider_name' configured successfully"
    echo "Config file: $config_file"
}

# ========================
#   Provider Switch Command
# ========================

cmd_switch_provider() {
    local provider="${1:-}"

    if [ -z "$provider" ]; then
        log_error "Usage: $SCRIPT_NAME <provider> [claude args...]"
        exit 1
    fi

    ensure_dirs_exist

    local config_file="${PROVIDERS_DIR}/${provider}.sh"

    if [ ! -f "$config_file" ]; then
        log_error "Provider '$provider' not configured"
        log_error "Available providers:"
        cmd_list_providers 2>/dev/null || echo "  (none configured yet)"
        exit 1
    fi

    # Clean slate - unset all ANTHROPIC variables
    unset_anthropic_vars

    # Source provider configuration
    # shellcheck source=/dev/null
    source "$config_file"

    # Save active provider
    echo "$provider" > "$ACTIVE_FILE"

    # Execute claude with remaining arguments
    shift
    exec claude "$@"
}

# ========================
#      List Command
# ========================

cmd_list_providers() {
    ensure_dirs_exist

    local active_provider=""
    if [ -f "$ACTIVE_FILE" ]; then
        active_provider=$(cat "$ACTIVE_FILE")
    fi

    local providers=()
    local has_providers=false

    # Collect all provider files
    while IFS= read -r -d '' provider_file; do
        has_providers=true
        providers+=("$(basename "$provider_file" .sh)")
    done < <(find "$PROVIDERS_DIR" -maxdepth 1 -name "*.sh" -print0 2>/dev/null)

    if [ "$has_providers" = false ]; then
        echo "No providers configured yet."
        echo "Use '$SCRIPT_NAME configure <provider>' to add a provider"
        return 0
    fi

    # Sort providers
    IFS=$'\n' sorted_providers=($(sort <<<"${providers[*]}"))
    unset IFS

    echo "Configured providers:"
    for provider in "${sorted_providers[@]}"; do
        local config_file="${PROVIDERS_DIR}/${provider}.sh"
        local base_url=$(grep "^export ANTHROPIC_BASE_URL=" "$config_file" | cut -d'=' -f2- | tr -d '"')
        local model=$(grep "^export ANTHROPIC_MODEL=" "$config_file" | cut -d'=' -f2- | tr -d '"')

        if [ "$provider" = "$active_provider" ]; then
            printf "  [*] %-15s %s (model: %s)\n" "$provider" "$base_url" "$model"
        else
            printf "  [ ] %-15s %s (model: %s)\n" "$provider" "$base_url" "$model"
        fi
    done
}

# ========================
#      Status Command
# ========================

cmd_status() {
    ensure_dirs_exist

    local active_provider=""
    if [ -f "$ACTIVE_FILE" ]; then
        active_provider=$(cat "$ACTIVE_FILE")
    fi

    if [ -z "$active_provider" ]; then
        echo "No provider active (using default Claude Code)"
        return 0
    fi

    local config_file="${PROVIDERS_DIR}/${active_provider}.sh"

    if [ ! -f "$config_file" ]; then
        echo "Active provider '$active_provider' config not found!"
        return 1
    fi

    echo "Active provider: $active_provider"
    echo "Config file: $config_file"
    echo
    echo "Environment variables:"
    grep "^export" "$config_file" | sed 's/export /  /' | sed "s/ANTHROPIC_AUTH_TOKEN=.*$/ANTHROPIC_AUTH_TOKEN=***REDACTED***/g"
}

# ========================
#   Default/Reset Command
# ========================

cmd_default() {
    unset_anthropic_vars
    rm -f "$ACTIVE_FILE" 2>/dev/null || true
    log_success "Reset to default Claude Code subscription"
    shift
    exec claude "$@"
}

# ========================
#      Remove Command
# ========================

cmd_remove() {
    local provider="${1:-}"

    if [ -z "$provider" ]; then
        log_error "Usage: $SCRIPT_NAME remove <provider>"
        exit 1
    fi

    ensure_dirs_exist

    local config_file="${PROVIDERS_DIR}/${provider}.sh"

    if [ ! -f "$config_file" ]; then
        log_error "Provider '$provider' not configured"
        exit 1
    fi

    if [ -t 0 ]; then
        read -p "Delete provider '$provider'? (y/n): " confirm </dev/tty
    else
        read -p "Delete provider '$provider'? (y/n): " confirm
    fi
    if ! [[ "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Deletion cancelled"
        exit 0
    fi

    rm -f "$config_file"

    # Clear active if this was the active provider
    if [ -f "$ACTIVE_FILE" ] && [ "$(cat "$ACTIVE_FILE")" = "$provider" ]; then
        rm -f "$ACTIVE_FILE"
    fi

    log_success "Provider '$provider' removed"
}

# ========================
#      Help Command
# ========================

cmd_help() {
    cat << 'EOF'
YACCS - Yet Another Claude Code Switcher
Manage multiple Claude Code provider configurations

USAGE:
  yaccs <command> [options]

COMMANDS:
  configure <provider>    Configure a new or existing provider
                         Prompts for: Base URL, API Key, Model ID(s)

  <provider>             Switch to a provider and run Claude Code
                         Example: yaccs glm
                         Additional args are passed to claude

  list                   List all configured providers
                         Shows active provider with [*]

  status                 Show currently active provider
                         Displays current environment variables

  default                Reset to default Claude Code subscription
                         Unsets all provider environment variables

  reset                  Alias for 'default'

  remove <provider>      Remove a configured provider

  help                   Show this help message

EXAMPLES:
  # Configure a new provider
  yaccs configure openrouter

  # Switch to a provider
  yaccs glm

  # Use provider with Claude Code arguments
  yaccs chutes --help

  # List all providers
  yaccs list

  # Check which provider is active
  yaccs status

  # Switch back to default Claude subscription
  yaccs default

  # Remove a provider
  yaccs remove openrouter

CONFIGURATION:
  Providers are stored in: ~/.yaccs/providers/
  Active provider tracking: ~/.yaccs/active
  Each provider file contains environment variable exports

NOTES:
  - API Keys are stored in plaintext in ~/.yaccs/providers/
  - Files are created with restrictive permissions (chmod 600)
  - Use 'yaccs default' before sharing your system
EOF
}

# ========================
#        Main Router
# ========================

main() {
    local command="${1:-help}"

    case "$command" in
        configure)
            cmd_configure "$2"
            ;;
        list)
            cmd_list_providers
            ;;
        status)
            cmd_status
            ;;
        default|reset)
            cmd_default "${@:2}"
            ;;
        remove)
            cmd_remove "$2"
            ;;
        help|-h|--help)
            cmd_help
            ;;
        *)
            # Treat as provider name - switch and run claude
            cmd_switch_provider "$@"
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
