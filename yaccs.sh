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

# ========================
#   Helper Functions
# ========================

# Prompt user for input, handling both TTY and non-TTY contexts
prompt_input() {
    local prompt="$1"
    local is_silent="${2:-false}"
    local input

    if [ -t 0 ]; then
        if [ "$is_silent" = true ]; then
            read -s -p "$prompt" input </dev/tty
        else
            read -p "$prompt" input </dev/tty
        fi
    else
        if [ "$is_silent" = true ]; then
            read -s -p "$prompt" input
        else
            read -p "$prompt" input
        fi
    fi
    echo "$input"
}

# Prompt user for yes/no confirmation
confirm_action() {
    local prompt="$1"
    local response

    response=$(prompt_input "$prompt (y/n): ")
    [[ "$response" =~ ^[Yy]$ ]]
}

# Extract a configuration value from a provider config file
get_config_value() {
    local config_file="$1"
    local var_name="$2"

    grep "^export ${var_name}=" "$config_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || echo ""
}

# Redact API key for display (show first and last N characters)
redact_key() {
    local key="$1"
    local length=5
    echo "${key:0:$length}...${key: -$length}"
}

# Write provider configuration file
write_config_file() {
    local config_file="$1"
    local api_key="$2"
    local base_url="$3"
    local model_id="$4"
    local haiku_model="$5"
    local sonnet_model="$6"
    local opus_model="$7"
    local subagent_model="$8"
    local small_fast_model="$9"

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
}

# Unset all ANTHROPIC_* environment variables
unset_anthropic_vars() {
    local var
    for var in ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL ANTHROPIC_MODEL \
               ANTHROPIC_DEFAULT_HAIKU_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL \
               ANTHROPIC_DEFAULT_OPUS_MODEL CLAUDE_CODE_SUBAGENT_MODEL \
               ANTHROPIC_SMALL_FAST_MODEL CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC; do
        unset "$var" 2>/dev/null || true
    done
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
    local keep_existing=false

    # Check if provider already exists
    if [ -f "$config_file" ]; then
        log_info "Found existing configuration for '$provider_name'"
        if confirm_action "Keep existing values?"; then
            keep_existing=true
        fi
    fi

    # Prompt for Base URL
    local base_url=""
    if [ "$keep_existing" = true ]; then
        base_url=$(get_config_value "$config_file" "ANTHROPIC_BASE_URL")
        echo "Base URL (current: $base_url): "
        base_url_input=$(prompt_input "> ")
        [ -n "$base_url_input" ] && base_url="$base_url_input"
    else
        echo "Enter Base URL (e.g., https://api.example.com):"
        base_url=$(prompt_input "> ")
    fi

    if [ -z "$base_url" ]; then
        log_error "Base URL cannot be empty"
        exit 1
    fi

    # Prompt for API Key
    local api_key=""
    if [ "$keep_existing" = true ]; then
        echo "Enter API Key (leave blank to keep existing):"
        api_key_input=$(prompt_input "> " true)
        echo
        if [ -n "$api_key_input" ]; then
            api_key="$api_key_input"
        else
            api_key=$(get_config_value "$config_file" "ANTHROPIC_AUTH_TOKEN")
        fi
    else
        echo "Enter API Key:"
        api_key=$(prompt_input "> " true)
        echo
    fi

    if [ -z "$api_key" ]; then
        log_error "API Key cannot be empty"
        exit 1
    fi

    # Prompt for Main Model ID
    local model_id=""
    if [ "$keep_existing" = true ]; then
        model_id=$(get_config_value "$config_file" "ANTHROPIC_MODEL")
        echo "Main Model ID (current: $model_id): "
        model_input=$(prompt_input "> ")
        [ -n "$model_input" ] && model_id="$model_input"
    else
        echo "Enter Main Model ID (e.g., claude-opus-4-5):"
        model_id=$(prompt_input "> ")
    fi

    if [ -z "$model_id" ]; then
        log_error "Model ID cannot be empty"
        exit 1
    fi

    # Initialize tier models
    local haiku_model="$model_id"
    local sonnet_model="$model_id"
    local opus_model="$model_id"
    local subagent_model="$model_id"
    local small_fast_model="$model_id"

    # Ask about per-tier customization
    echo
    if confirm_action "Customize models per tier (haiku/sonnet/opus/subagent)?"; then
        echo "Haiku model (fast) [default: $model_id]: "
        haiku_input=$(prompt_input "> ")
        [ -n "$haiku_input" ] && haiku_model="$haiku_input"

        echo "Sonnet model (balanced) [default: $model_id]: "
        sonnet_input=$(prompt_input "> ")
        [ -n "$sonnet_input" ] && sonnet_model="$sonnet_input"

        echo "Opus model (powerful) [default: $model_id]: "
        opus_input=$(prompt_input "> ")
        [ -n "$opus_input" ] && opus_model="$opus_input"

        echo "Subagent model [default: $model_id]: "
        subagent_input=$(prompt_input "> ")
        [ -n "$subagent_input" ] && subagent_model="$subagent_input"

        echo "Small/Fast model [default: $model_id]: "
        smallfast_input=$(prompt_input "> ")
        [ -n "$smallfast_input" ] && small_fast_model="$smallfast_input"
    fi

    # Show preview
    echo
    log_info "Configuration preview:"
    echo "  Base URL: $base_url"
    echo "  API Key: $(redact_key "$api_key")"
    echo "  Main Model: $model_id"
    echo "  Haiku Model: $haiku_model"
    echo "  Sonnet Model: $sonnet_model"
    echo "  Opus Model: $opus_model"
    echo "  Subagent Model: $subagent_model"
    echo "  Small/Fast Model: $small_fast_model"
    echo

    if ! confirm_action "Save configuration?"; then
        log_info "Configuration cancelled"
        exit 0
    fi

    # Write configuration file
    write_config_file "$config_file" "$api_key" "$base_url" "$model_id" \
                      "$haiku_model" "$sonnet_model" "$opus_model" \
                      "$subagent_model" "$small_fast_model"

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
        local base_url=$(get_config_value "$config_file" "ANTHROPIC_BASE_URL")
        local model=$(get_config_value "$config_file" "ANTHROPIC_MODEL")

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
    local api_key=$(get_config_value "$config_file" "ANTHROPIC_AUTH_TOKEN")
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
#      Modify Command
# ========================

cmd_modify() {
    local provider_name="${1:-}"

    if [ -z "$provider_name" ]; then
        log_error "Usage: $SCRIPT_NAME modify <provider>"
        exit 1
    fi

    ensure_dirs_exist

    local config_file="${PROVIDERS_DIR}/${provider_name}.sh"

    # Validate that the provider exists
    if [ ! -f "$config_file" ]; then
        log_error "Provider '$provider_name' not configured"
        exit 1
    fi

    # Load current configuration values
    local current_base_url=$(get_config_value "$config_file" "ANTHROPIC_BASE_URL")
    local current_api_key=$(get_config_value "$config_file" "ANTHROPIC_AUTH_TOKEN")
    local current_model_id=$(get_config_value "$config_file" "ANTHROPIC_MODEL")
    local current_haiku_model=$(get_config_value "$config_file" "ANTHROPIC_DEFAULT_HAIKU_MODEL" || echo "$current_model_id")
    local current_sonnet_model=$(get_config_value "$config_file" "ANTHROPIC_DEFAULT_SONNET_MODEL" || echo "$current_model_id")
    local current_opus_model=$(get_config_value "$config_file" "ANTHROPIC_DEFAULT_OPUS_MODEL" || echo "$current_model_id")
    local current_subagent_model=$(get_config_value "$config_file" "CLAUDE_CODE_SUBAGENT_MODEL" || echo "$current_model_id")
    local current_small_fast_model=$(get_config_value "$config_file" "ANTHROPIC_SMALL_FAST_MODEL" || echo "$current_model_id")

    # Display current configuration in a user-friendly format
    echo "Current configuration for '$provider_name':"
    echo "  0. Provider Name: $provider_name"
    echo "  1. Base URL: $current_base_url"
    echo "  2. API Key: $(redact_key "$current_api_key") (${#current_api_key} chars)"
    echo "  3. Main Model: $current_model_id"
    echo "  4. Haiku Model: $current_haiku_model"
    echo "  5. Sonnet Model: $current_sonnet_model"
    echo "  6. Opus Model: $current_opus_model"
    echo "  7. Subagent Model: $current_subagent_model"
    echo "  8. Small/Fast Model: $current_small_fast_model"
    echo

    # Menu-driven interface for selecting fields to modify
    local fields_to_modify=()
    while true; do
        echo "Select fields to modify (enter number, 'done' when finished):"
        selection=$(prompt_input "> ")

        case "$selection" in
            0|1|2|3|4|5|6|7|8)
                if [[ ! " ${fields_to_modify[@]:-} " =~ " ${selection} " ]]; then
                    fields_to_modify+=("$selection")
                    echo "Added field $selection to modification list"
                else
                    echo "Field $selection already selected"
                fi
                ;;
            done|DONE)
                break
                ;;
            *)
                echo "Invalid selection. Please enter a number (0-8) or 'done'."
                ;;
        esac
    done

    # If no fields selected, exit
    if [ ${#fields_to_modify[@]} -eq 0 ]; then
        log_info "No fields selected for modification. Exiting."
        exit 0
    fi

    # Initialize new values with current values
    local new_provider_name="$provider_name"
    local new_base_url="$current_base_url"
    local new_api_key="$current_api_key"
    local new_model_id="$current_model_id"
    local new_haiku_model="$current_haiku_model"
    local new_sonnet_model="$current_sonnet_model"
    local new_opus_model="$current_opus_model"
    local new_subagent_model="$current_subagent_model"
    local new_small_fast_model="$current_small_fast_model"

    # Process each selected field
    for field in "${fields_to_modify[@]}"; do
        case "$field" in
            0)
                echo "Enter new Provider Name (current: $provider_name):"
                if [ -t 0 ]; then
                    read -p "> " input </dev/tty
                else
                    read -p "> " input
                fi
                if [ -n "$input" ]; then
                    # Validate that the new name doesn't conflict with an existing provider
                    local new_config_file="${PROVIDERS_DIR}/${input}.sh"
                    if [ "$input" != "$provider_name" ] && [ -f "$new_config_file" ]; then
                        echo "Warning: Provider '$input' already exists. This will overwrite it."
                        if [ -t 0 ]; then
                            read -p "Continue? (y/n): " confirm </dev/tty
                        else
                            read -p "Continue? (y/n): " confirm
                        fi
                        if ! [[ "$confirm" =~ ^[Yy]$ ]]; then
                            echo "Skipping provider name change."
                            continue
                        fi
                    fi
                    new_provider_name="$input"
                fi
                ;;
            1)
                echo "Enter new Base URL (current: $current_base_url):"
                if [ -t 0 ]; then
                    read -p "> " input </dev/tty
                else
                    read -p "> " input
                fi
                if [ -n "$input" ]; then
                    new_base_url="$input"
                fi
                ;;
            2)
                echo "Enter new API Key (current: ${current_api_key:0:5}...${current_api_key: -5}):"
                if [ -t 0 ]; then
                    read -s -p "> " input </dev/tty
                else
                    read -p "> " input
                fi
                echo
                if [ -n "$input" ]; then
                    new_api_key="$input"
                fi
                ;;
            3)
                echo "Enter new Main Model ID (current: $current_model_id):"
                if [ -t 0 ]; then
                    read -p "> " input </dev/tty
                else
                    read -p "> " input
                fi
                if [ -n "$input" ]; then
                    new_model_id="$input"
                fi
                ;;
            4)
                echo "Enter new Haiku Model (current: $current_haiku_model):"
                if [ -t 0 ]; then
                    read -p "> " input </dev/tty
                else
                    read -p "> " input
                fi
                if [ -n "$input" ]; then
                    new_haiku_model="$input"
                fi
                ;;
            5)
                echo "Enter new Sonnet Model (current: $current_sonnet_model):"
                if [ -t 0 ]; then
                    read -p "> " input </dev/tty
                else
                    read -p "> " input
                fi
                if [ -n "$input" ]; then
                    new_sonnet_model="$input"
                fi
                ;;
            6)
                echo "Enter new Opus Model (current: $current_opus_model):"
                if [ -t 0 ]; then
                    read -p "> " input </dev/tty
                else
                    read -p "> " input
                fi
                if [ -n "$input" ]; then
                    new_opus_model="$input"
                fi
                ;;
            7)
                echo "Enter new Subagent Model (current: $current_subagent_model):"
                if [ -t 0 ]; then
                    read -p "> " input </dev/tty
                else
                    read -p "> " input
                fi
                if [ -n "$input" ]; then
                    new_subagent_model="$input"
                fi
                ;;
            8)
                echo "Enter new Small/Fast Model (current: $current_small_fast_model):"
                if [ -t 0 ]; then
                    read -p "> " input </dev/tty
                else
                    read -p "> " input
                fi
                if [ -n "$input" ]; then
                    new_small_fast_model="$input"
                fi
                ;;
        esac
    done

    # Validate inputs (only validate if we're not renaming the provider)
    if [ "$new_provider_name" = "$provider_name" ] || [ -n "$new_base_url" ]; then
        if [ -z "$new_base_url" ]; then
            log_error "Base URL cannot be empty"
            exit 1
        fi
    fi

    if [ "$new_provider_name" = "$provider_name" ] || [ -n "$new_api_key" ]; then
        if [ -z "$new_api_key" ]; then
            log_error "API Key cannot be empty"
            exit 1
        fi
    fi

    if [ "$new_provider_name" = "$provider_name" ] || [ -n "$new_model_id" ]; then
        if [ -z "$new_model_id" ]; then
            log_error "Model ID cannot be empty"
            exit 1
        fi
    fi

    # Preview of changes
    echo
    log_info "Changes preview:"
    [ "$provider_name" != "$new_provider_name" ] && echo "  Provider Name: $provider_name -> $new_provider_name"
    [ "$current_base_url" != "$new_base_url" ] && echo "  Base URL: $current_base_url -> $new_base_url"
    [ "$current_api_key" != "$new_api_key" ] && echo "  API Key: *** -> ***"
    [ "$current_model_id" != "$new_model_id" ] && echo "  Main Model: $current_model_id -> $new_model_id"
    [ "$current_haiku_model" != "$new_haiku_model" ] && echo "  Haiku Model: $current_haiku_model -> $new_haiku_model"
    [ "$current_sonnet_model" != "$new_sonnet_model" ] && echo "  Sonnet Model: $current_sonnet_model -> $new_sonnet_model"
    [ "$current_opus_model" != "$new_opus_model" ] && echo "  Opus Model: $current_opus_model -> $new_opus_model"
    [ "$current_subagent_model" != "$new_subagent_model" ] && echo "  Subagent Model: $current_subagent_model -> $new_subagent_model"
    [ "$current_small_fast_model" != "$new_small_fast_model" ] && echo "  Small/Fast Model: $current_small_fast_model -> $new_small_fast_model"
    echo

    # Confirm changes
    if [ -t 0 ]; then
        read -p "Apply changes? (y/n): " confirm </dev/tty
    else
        read -p "Apply changes? (y/n): " confirm
    fi
    if ! [[ "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Modification cancelled"
        exit 0
    fi

    # Handle provider renaming
    local new_config_file="$config_file"
    if [ "$provider_name" != "$new_provider_name" ]; then
        new_config_file="${PROVIDERS_DIR}/${new_provider_name}.sh"
        # If renaming to an existing provider, remove the old one first
        if [ -f "$new_config_file" ]; then
            rm -f "$new_config_file"
        fi
        # Move the old config file to the new name
        mv "$config_file" "$new_config_file"
        # Update active provider file if necessary
        if [ -f "$ACTIVE_FILE" ] && [ "$(cat "$ACTIVE_FILE")" = "$provider_name" ]; then
            echo "$new_provider_name" > "$ACTIVE_FILE"
        fi
        config_file="$new_config_file"
    fi

    # Write configuration file
    write_config_file "$config_file" "$new_api_key" "$new_base_url" "$new_model_id" \
                      "$new_haiku_model" "$new_sonnet_model" "$new_opus_model" \
                      "$new_subagent_model" "$new_small_fast_model"
    
    if [ "$provider_name" != "$new_provider_name" ]; then
        log_success "Provider '$provider_name' renamed to '$new_provider_name' and modified successfully"
    else
        log_success "Provider '$provider_name' modified successfully"
    fi
    echo "Config file: $config_file"
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

    if ! confirm_action "Delete provider '$provider'?"; then
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

  modify <provider>       Modify an existing provider configuration
                         Interactive menu to update specific fields

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
        modify)
            cmd_modify "$2"
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
