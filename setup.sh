#!/usr/bin/env bash

# Unified dotfiles setup script
# Replaces install.sh, update.sh, and cleanup.sh with a modular approach

set -Eeuo pipefail
IFS=$'\n\t'

# Ensure we have a basic PATH for essential Unix tools
if [[ -z "${PATH:-}" ]]; then
    export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"
fi

#==============================================================================
# Constants
#==============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LIB_DIR="$SCRIPT_DIR/.lib"
readonly VERSION="2.0.0"

#==============================================================================
# Load All Modules
#==============================================================================

# shellcheck source=.lib/core.sh
source "$LIB_DIR/core.sh"
# shellcheck source=.lib/packages.sh
source "$LIB_DIR/packages.sh"
# shellcheck source=.lib/dotfiles.sh
source "$LIB_DIR/dotfiles.sh"
# shellcheck source=.lib/repos.sh
source "$LIB_DIR/repos.sh"
# shellcheck source=.lib/system.sh
source "$LIB_DIR/system.sh"

#==============================================================================
# Help System
#==============================================================================

show_help() {
    cat << EOF
Dotfiles Setup System v$VERSION

USAGE:
    ./setup.sh <command> [options]

COMMANDS:
    install     Set up dotfiles and install packages
    update      Update packages and git repositories  
    cleanup     Clean package caches and old files
    help        Show this help message

OPTIONS:
    --debug             Enable verbose debug logging
    --help, -h          Show help for command

BYPASS FLAGS (Environment Variables):
    BYPASS_VERIFY_ESSENTIALS=true   Skip essential tool verification
    BYPASS_GIT_REPOS=true           Skip git repository operations
    BYPASS_OS_PACKAGES=true         Skip OS package installation
    BYPASS_CARGO=true               Skip Cargo package installation
    BYPASS_NPM=true                 Skip NPM package installation
    BYPASS_SETUP_DOTFILES=true      Skip dotfile symlink setup
    BYPASS_MACOS_DEFAULTS=true      Skip macOS system defaults
    BYPASS_OS_UPDATES=true          Skip OS package updates

EXAMPLES:
    ./setup.sh install                    # Full installation
    ./setup.sh update                     # Update everything
    BYPASS_OS_PACKAGES=true ./setup.sh install  # Skip OS packages
    DEBUG=true ./setup.sh install --debug # Verbose logging

For more details, see: https://github.com/yourusername/dotfiles
EOF
}

show_install_help() {
    cat << EOF
Install Command - Set up dotfiles and install packages

USAGE:
    ./setup.sh install [options]

DESCRIPTION:
    Performs a complete dotfiles installation:
    - Verifies essential tools are installed
    - Installs OS packages (brew, apt, etc.)
    - Installs language-specific packages (cargo, npm)
    - Sets up dotfile symlinks
    - Clones and configures external repositories
    - Applies system configurations (macOS defaults)

OPTIONS:
    --debug      Enable verbose debug logging
    --help, -h   Show this help

Use bypass flags to skip specific installation steps.
EOF
}

show_update_help() {
    cat << EOF
Update Command - Update packages and repositories

USAGE:
    ./setup.sh update [options]

DESCRIPTION:
    Updates all installed components:
    - Updates OS packages and package managers
    - Updates language-specific packages (cargo, npm)
    - Pulls latest changes from git repositories
    - Applies system updates (macOS only)

OPTIONS:
    --debug      Enable verbose debug logging
    --help, -h   Show this help

Use bypass flags to skip specific update steps.
EOF
}

show_cleanup_help() {
    cat << EOF
Cleanup Command - Clean caches and old files

USAGE:
    ./setup.sh cleanup [options]

DESCRIPTION:
    Performs system maintenance:
    - Cleans package manager caches
    - Removes old/unused packages
    - Clears temporary files

OPTIONS:
    --debug      Enable verbose debug logging
    --help, -h   Show this help
EOF
}

#==============================================================================
# Command Implementations
#==============================================================================

cmd_install() {
    log_info "Starting dotfiles installation..."
    
    local install_failed=false
    
    # Essential tool verification
    if ! should_skip "VERIFY_ESSENTIALS"; then
        log_info "Verifying essential tools..."
        local missing_tools=()
        local essential_tools=("git" "zsh" "curl")
        
        for tool in "${essential_tools[@]}"; do
            if ! command_exists "$tool"; then
                missing_tools+=("$tool")
            fi
        done
        
        if [[ ${#missing_tools[@]} -gt 0 ]]; then
            log_error "Missing required tools: ${missing_tools[*]}"
            log_error "Please install the missing tools and run again"
            return 1
        fi
        
        log_success "All essential tools are available"
        
        # OS-specific tool verification
        if is_macos && ! should_skip "OS_PACKAGES"; then
            if ! command_exists brew; then
                log_error "Homebrew is required for macOS package management"
                log_error "Install it from: https://brew.sh"
                return 1
            fi
        elif is_linux && ! should_skip "OS_PACKAGES"; then
            local package_manager_found=false
            local available_managers=()
            
            # Check for available package managers
            if command_exists apt; then
                available_managers+=("apt")
                package_manager_found=true
            fi
            if command_exists dnf; then
                available_managers+=("dnf")
                package_manager_found=true
            fi
            if command_exists pacman; then
                available_managers+=("pacman")
                package_manager_found=true
            fi
            if command_exists nix-env; then
                available_managers+=("nix")
                package_manager_found=true
            fi
            
            if [[ "$package_manager_found" == "false" ]]; then
                log_error "No supported package manager found for Linux"
                log_error "Supported: apt, dnf, pacman, nix-env"
                return 1
            else
                log_success "Package manager(s) available: ${available_managers[*]}"
            fi
        fi
    fi
    
    # Install external repositories
    if ! install_repositories; then
        install_failed=true
    fi
    
    # Install packages
    if ! install_packages; then
        install_failed=true
    fi
    
    # Set up dotfiles
    if ! setup_dotfiles; then
        install_failed=true
    fi
    
    # Apply system defaults
    if ! apply_system_defaults; then
        install_failed=true
    fi
    
    if [[ "$install_failed" == "true" ]]; then
        log_error "Some installation steps failed"
        return 1
    else
        log_success "Dotfiles installation completed successfully!"
        return 0
    fi
}

cmd_update() {
    log_info "Starting dotfiles update..."
    
    local update_failed=false
    
    # Update external repositories
    if ! update_repositories; then
        update_failed=true
    fi
    
    # Update packages
    if ! update_packages; then
        update_failed=true
    fi
    
    if [[ "$update_failed" == "true" ]]; then
        log_error "Some update steps failed"
        return 1
    else
        log_success "Dotfiles update completed successfully!"
        return 0
    fi
}

cmd_cleanup() {
    log_info "Starting package cleanup..."
    
    # Clean package caches via packages module
    if ! cleanup_all_packages; then
        log_error "Package cleanup failed"
        return 1
    else
        log_success "Package cleanup completed successfully!"
        return 0
    fi
}

#==============================================================================
# Argument Processing
#==============================================================================

parse_command_args() {
    local command="$1"
    shift
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                case $command in
                    install) show_install_help ;;
                    update) show_update_help ;;
                    cleanup) show_cleanup_help ;;
                    *) show_help ;;
                esac
                exit 0
                ;;
            --*)
                log_error "Unknown option for $command: $1"
                echo "Run './setup.sh $command --help' for usage information."
                exit 1
                ;;
            *)
                log_error "Unexpected argument for $command: $1"
                echo "Run './setup.sh $command --help' for usage information."
                exit 1
                ;;
        esac
    done
}

#==============================================================================
# Main Entry Point
#==============================================================================

main() {
    # Initialize core module
    core_init
    
    # Parse global arguments directly
    while [[ $# -gt 0 ]]; do
        case $1 in
            --debug)
                export DEBUG=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            --*)
                log_error "Unknown global option: $1"
                echo "Run './setup.sh --help' for usage information."
                exit 1
                ;;
            *)
                # Found non-option argument, stop processing global args
                break
                ;;
        esac
    done
    
    # Check for command
    if [[ $# -eq 0 ]]; then
        log_error "No command specified"
        echo "Run './setup.sh --help' for usage information."
        exit 1
    fi
    
    local command="$1"
    shift
    
    # Parse command-specific arguments
    parse_command_args "$command" "$@"
    
    # Execute command
    case $command in
        install)
            cmd_install
            ;;
        update)
            cmd_update
            ;;
        cleanup)
            cmd_cleanup
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Run './setup.sh --help' for available commands."
            exit 1
            ;;
    esac
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
