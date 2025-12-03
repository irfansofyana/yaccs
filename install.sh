#!/bin/bash

################################################################################
# YACCS Installation Script
# Sets up the YACCS CLI tool and migrates existing configurations
################################################################################

set -euo pipefail

# ========================
#      Define Constants
# ========================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YACCS_DIR="${HOME}/.yaccs"
PROVIDERS_DIR="${YACCS_DIR}/providers"
INSTALL_TARGET="${HOME}/.local/bin/yaccs"
ALT_INSTALL_TARGET="/usr/local/bin/yaccs"

# ========================
#      Utility Functions
# ========================

log_info() {
    echo "[INFO] $*"
}

log_success() {
    echo "[ OK ] $*"
}

log_warning() {
    echo "[WARN] $*"
}

log_error() {
    echo "[ERR ] $*" >&2
}

# ========================
#        Main Setup
# ========================

main() {
    echo "========================================"
    echo "YACCS Installation Script"
    echo "========================================"
    echo

    # Create directory structure
    log_info "Creating directory structure..."
    mkdir -p "$PROVIDERS_DIR" || {
        log_error "Failed to create $PROVIDERS_DIR"
        exit 1
    }
    log_success "Directories created"
    echo

    # Install main script
    log_info "Installing yaccs command..."

    # Try to install to ~/.local/bin first
    if mkdir -p "${INSTALL_TARGET%/*}" 2>/dev/null; then
        cp "$SCRIPT_DIR/yaccs.sh" "$INSTALL_TARGET"
        chmod +x "$INSTALL_TARGET"
        log_success "Installed: $INSTALL_TARGET"
        INSTALLED_PATH="$INSTALL_TARGET"
    else
        # Fallback to /usr/local/bin (requires sudo)
        log_warning "Cannot write to ~/.local/bin, attempting /usr/local/bin (may require sudo)..."
        if sudo cp "$SCRIPT_DIR/yaccs.sh" "$ALT_INSTALL_TARGET" 2>/dev/null && \
           sudo chmod +x "$ALT_INSTALL_TARGET" 2>/dev/null; then
            log_success "Installed: $ALT_INSTALL_TARGET"
            INSTALLED_PATH="$ALT_INSTALL_TARGET"
        else
            log_error "Failed to install yaccs command"
            exit 1
        fi
    fi
    echo

    # Check if install path is in PATH
    log_info "Checking PATH configuration..."
    local install_dir="${INSTALLED_PATH%/*}"
    local path_ok=false

    if [[ ":$PATH:" == *":$install_dir:"* ]]; then
        log_success "$install_dir is already in PATH"
        path_ok=true
    else
        log_warning "$install_dir is not in PATH"
        path_ok=false
    fi

    if [ "$path_ok" = false ]; then
        echo
        log_info "To add $install_dir to PATH, add the following to your shell config:"
        echo
        if [ "$install_dir" = "${HOME}/.local/bin" ]; then
            echo "For bash (~/.bashrc):"
            echo '  export PATH="$HOME/.local/bin:$PATH"'
            echo
            echo "For zsh (~/.zshrc):"
            echo '  export PATH="$HOME/.local/bin:$PATH"'
        else
            echo "For bash (~/.bashrc):"
            echo '  export PATH="/usr/local/bin:$PATH"'
            echo
            echo "For zsh (~/.zshrc):"
            echo '  export PATH="/usr/local/bin:$PATH"'
        fi
        echo
        if [ -t 0 ]; then
            read -p "Add to PATH now? (y/n): " add_to_path </dev/tty
        else
            read -p "Add to PATH now? (y/n): " add_to_path
        fi
        if [[ "$add_to_path" =~ ^[Yy]$ ]]; then
            # Detect shell config files
            local shell_config=""
            if [ -f "${HOME}/.bashrc" ]; then
                shell_config="${HOME}/.bashrc"
            elif [ -f "${HOME}/.bash_profile" ]; then
                shell_config="${HOME}/.bash_profile"
            elif [ -f "${HOME}/.zshrc" ]; then
                shell_config="${HOME}/.zshrc"
            fi

            if [ -n "$shell_config" ]; then
                # Add PATH export if not already present
                if ! grep -q "export PATH=.*${install_dir}" "$shell_config" 2>/dev/null; then
                    echo "export PATH=\"${install_dir}:\$PATH\"" >> "$shell_config"
                    log_success "Added to $shell_config"
                    echo "Run: source $shell_config"
                fi
            else
                log_error "Could not find shell config file"
            fi
        fi
    fi
    echo

    # Verify installation
    log_info "Verifying installation..."
    if command -v yaccs &>/dev/null; then
        log_success "yaccs is available in PATH"
    else
        log_warning "yaccs not yet in PATH (may need to reload shell)"
        log_info "Try running: source ~/.bashrc  (or ~/.zshrc)"
    fi
    echo

    # Show existing providers
    log_info "Configured providers:"
    if ls "$PROVIDERS_DIR"/*.sh &>/dev/null; then
        for provider_file in "$PROVIDERS_DIR"/*.sh; do
            local provider_name=$(basename "$provider_file" .sh)
            local base_url=$(grep "^export ANTHROPIC_BASE_URL=" "$provider_file" | cut -d'=' -f2- | tr -d '"' || echo "N/A")
            printf "  - %-15s %s\n" "$provider_name" "$base_url"
        done
    else
        echo "  (none configured yet)"
    fi
    echo

    # Summary
    echo "========================================"
    echo "Installation Complete!"
    echo "========================================"
    echo
    echo "Configuration directory: $YACCS_DIR"
    echo "Providers directory: $PROVIDERS_DIR"
    echo
    echo "Next steps:"
    echo "1. Configure a provider:"
    echo "   yaccs configure <provider>"
    echo
    echo "2. Switch to a provider:"
    echo "   yaccs glm"
    echo
    echo "3. View all commands:"
    echo "   yaccs help"
    echo
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
