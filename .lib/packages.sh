#!/usr/bin/env bash

# Package management module
# Handles installation and updates for OS packages and language-specific packages

#==============================================================================
# Package List Management
#==============================================================================

# Check if a package list file exists
check_packagelist() {
    local packagelist="$1"
    log_debug "checking package list: $packagelist"
    
    if [[ ! -f "$packagelist" ]]; then
        log_warning "Package list '$packagelist' not found, skipping"
        return 1
    fi
    
    log_debug "package list '$packagelist' exists"
    return 0
}

# Read and process a package list file (strips comments and empty lines)
read_packagelist() {
    local packagelist="$1"
    log_debug "reading package list: $packagelist"
    
    grep -vE '^\s*#|^\s*$' "$packagelist" | awk '{print $1}'
}

# Install packages from a list with error handling
install_from_packagelist() {
    local packagelist="$1"
    local install_cmd="$2"
    local description="$3"
    
    if ! check_packagelist "$packagelist"; then
        return 0
    fi
    
    log_info "Installing $description..."
    
    local packages
    packages=$(read_packagelist "$packagelist")
    
    if [[ -z "$packages" ]]; then
        log_warning "No packages found in $packagelist"
        return 0
    fi
    
    # Install packages one by one for better error reporting
    local failed_packages=()
    while IFS= read -r package; do
        log_debug "installing package: $package"
        if eval "$install_cmd $package"; then
            log_debug "successfully installed: $package"
        else
            log_warning "Failed to install package: $package"
            failed_packages+=("$package")
        fi
    done <<< "$packages"
    
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        log_warning "Failed to install some $description: ${failed_packages[*]}"
    else
        log_success "All $description installed successfully"
    fi
}

#==============================================================================
# OS Package Management
#==============================================================================

# Install macOS packages via Homebrew
install_macos_packages() {
    log_debug "installing macOS packages"
    
    if should_skip "OS_PACKAGES"; then
        return 0
    fi
    
    require_command brew
    
    # Homebrew packages (includes both regular packages and casks)
    install_from_packagelist \
        "packagelists/homebrew" \
        "brew install" \
        "Homebrew packages"
}

# Install Linux packages based on distribution family
install_linux_packages() {
    log_debug "installing Linux packages for $DISTRO_FAMILY"
    
    if should_skip "OS_PACKAGES"; then
        return 0
    fi
    
    case "$DISTRO_FAMILY" in
        debian)
            install_debian_packages
            ;;
        fedora)
            install_fedora_packages
            ;;
        arch)
            install_arch_packages
            ;;
        nixos)
            install_nixos_packages
            ;;
        *)
            log_warning "Unsupported Linux distribution family: $DISTRO_FAMILY"
            ;;
    esac
    
    # Install Flatpak packages if available
    if command_exists flatpak; then
        install_from_packagelist \
            "packagelists/flatpak" \
            "flatpak install -y --noninteractive flathub" \
            "Flatpak packages"
    fi
}

# Debian/Ubuntu package installation
install_debian_packages() {
    log_debug "installing Debian packages"
    require_command apt
    
    log_info "Updating package database..."
    sudo apt-get update
    
    install_from_packagelist \
        "packagelists/deb" \
        "sudo apt-get install -y" \
        "APT packages"
}

# Fedora package installation
install_fedora_packages() {
    log_debug "installing Fedora packages"
    require_command dnf
    
    install_from_packagelist \
        "packagelists/fedora" \
        "sudo dnf install -y" \
        "DNF packages"
}

# Arch package installation
install_arch_packages() {
    log_debug "installing Arch packages"
    require_command pacman
    
    install_from_packagelist \
        "packagelists/pacman" \
        "sudo pacman -S --noconfirm --needed" \
        "Pacman packages"
}

# NixOS package installation
install_nixos_packages() {
    log_debug "installing NixOS packages"
    require_command nix-env
    
    install_from_packagelist \
        "packagelists/nix" \
        "nix-env -iA nixos" \
        "Nix packages"
}

#==============================================================================
# Language-Specific Package Management
#==============================================================================

# Install Cargo packages
install_cargo_packages() {
    log_debug "installing Cargo packages"
    
    if should_skip "CARGO"; then
        return 0
    fi
    
    require_command cargo
    
    install_from_packagelist \
        "packagelists/cargo" \
        "cargo install" \
        "Cargo packages"
}

# Install NPM packages globally
install_npm_packages() {
    log_debug "installing NPM packages"
    
    if should_skip "NPM"; then
        return 0
    fi
    
    require_command npm
    
    install_from_packagelist \
        "packagelists/npm" \
        "npm install -g" \
        "NPM packages"
}

#==============================================================================
# Package Updates
#==============================================================================

# Update OS packages
update_os_packages() {
    log_debug "updating OS packages"
    
    if should_skip "OS_UPDATES"; then
        return 0
    fi
    
    if is_macos; then
        update_macos_packages
    elif is_linux; then
        update_linux_packages
    fi
}

# Update macOS packages
update_macos_packages() {
    log_debug "updating macOS packages"
    
    if command_exists brew; then
        log_info "Updating Homebrew..."
        brew update
        brew upgrade
    fi
    
    if command_exists softwareupdate; then
        log_info "Checking for system updates..."
        sudo softwareupdate --all --install --force
    fi
}

# Update Linux packages
update_linux_packages() {
    log_debug "updating Linux packages for $DISTRO_FAMILY"
    
    case "$DISTRO_FAMILY" in
        debian)
            if command_exists apt-get; then
                log_info "Updating APT packages..."
                sudo apt-get update
                sudo apt-get upgrade -y
            fi
            ;;
        fedora)
            if command_exists dnf; then
                log_info "Updating DNF packages..."
                sudo dnf upgrade -y
            fi
            ;;
        arch)
            if command_exists pacman; then
                log_info "Updating Pacman packages..."
                sudo pacman -Syu --noconfirm
            fi
            ;;
        nixos)
            if command_exists nix-env; then
                log_info "Updating Nix packages..."
                nix-env --upgrade
            fi
            ;;
    esac
    
    # Update Flatpak packages
    if command_exists flatpak; then
        log_info "Updating Flatpak packages..."
        flatpak update -y
    fi
}

# Update language-specific packages
update_language_packages() {
    log_debug "updating language packages"
    
    # Update Cargo packages
    if ! should_skip "CARGO" && command_exists cargo; then
        # Ensure cargo-update is installed
        if ! cargo install --list | grep -q "^cargo-update v"; then
            log_info "Installing cargo-update..."
            cargo install cargo-update
        fi
        
        log_info "Updating Cargo packages..."
        cargo install-update -a
    fi
    
    # Update NPM packages
    if ! should_skip "NPM" && command_exists npm; then
        log_info "Updating NPM packages..."
        npm update -g
    fi
}

#==============================================================================
# Package Cleanup
#==============================================================================

# Clean package caches and old packages
cleanup_packages() {
    log_debug "cleaning packages"
    
    if is_macos; then
        cleanup_macos_packages
    elif is_linux; then
        cleanup_linux_packages
    fi
}

# Clean macOS package caches
cleanup_macos_packages() {
    log_debug "cleaning macOS packages"
    
    if command_exists brew; then
        log_info "Cleaning Homebrew caches..."
        brew cleanup -s
        rm -rf "$(brew --cache)"
    fi
}

# Clean Linux package caches
cleanup_linux_packages() {
    log_debug "cleaning Linux packages for $DISTRO_FAMILY"
    
    case "$DISTRO_FAMILY" in
        debian)
            if command_exists apt-get; then
                log_info "Cleaning APT cache..."
                sudo apt-get autoremove -y
                sudo apt-get autoclean -y
            fi
            ;;
        fedora)
            if command_exists dnf; then
                log_info "Cleaning DNF cache..."
                sudo dnf autoremove -y
                sudo dnf clean all
            fi
            ;;
        arch)
            if command_exists pacman; then
                log_info "Cleaning Pacman cache..."
                sudo pacman -Sc --noconfirm
            fi
            ;;
        nixos)
            if command_exists nix-collect-garbage; then
                log_info "Collecting Nix garbage..."
                nix-collect-garbage -d
            fi
            ;;
    esac
}

#==============================================================================
# Main Package Functions
#==============================================================================

# Install all packages
install_packages() {
    log_debug "installing all packages"
    
    if is_macos; then
        install_macos_packages
    elif is_linux; then
        install_linux_packages
    fi
    
    install_cargo_packages
    install_npm_packages
}

# Update all packages
update_packages() {
    log_debug "updating all packages"
    
    update_os_packages
    update_language_packages
}

# Clean all package caches
cleanup_all_packages() {
    log_debug "cleaning all packages"
    
    cleanup_packages
}
