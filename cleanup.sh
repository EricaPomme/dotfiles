#!/usr/bin/env bash

set -euo pipefail

DEBUG=${DEBUG:-false}

# Load shared functions like logging and OS detection
source "$(dirname "$0")/install.sh"

cleanup_system() {
    log_debug "entering cleanup_system($(join_args "$@"))"

    detect_os

    case "$OS" in
        macos)
            if command -v brew &>/dev/null; then
                log_info "Cleaning Homebrew caches and old versions..."
                brew cleanup -s || log_warning "Homebrew cleanup failed"
                rm -rf "$(brew --cache)" || log_warning "Failed to remove Homebrew cache"
            fi
            ;;
        linux)
            detect_linux_distro
            case "$DISTRO_ID" in
            ubuntu | debian)
                if command -v apt-get &>/dev/null; then
                    log_info "Cleaning APT cache..."
                    sudo apt-get autoremove -y || log_warning "APT autoremove failed"
                    sudo apt-get autoclean -y || log_warning "APT autoclean failed"
                fi
                ;;
            fedora)
                if command -v dnf &>/dev/null; then
                    log_info "Cleaning DNF cache..."
                    sudo dnf autoremove -y || log_warning "DNF autoremove failed"
                    sudo dnf clean all || log_warning "DNF clean failed"
                fi
                ;;
            arch | endeavouros | cachyos | garuda)
                if command -v pacman &>/dev/null; then
                    log_info "Cleaning Pacman cache..."
                    sudo pacman -Sc --noconfirm || log_warning "Pacman cache cleanup failed"
                fi
                ;;
            nixos)
                if command -v nix-collect-garbage &>/dev/null; then
                    log_info "Collecting Nix garbage..."
                    nix-collect-garbage -d || log_warning "Nix garbage collection failed"
                fi
                ;;
            *)
                log_warning "Unsupported Linux distribution for cleanup: $DISTRO_ID"
                ;;
            esac
            ;;
            *)
                log_warning "Cleanup not supported on OS: $OS"
            ;;
    esac

    log_debug "exiting cleanup_system($(join_args "$@"))"
}

cleanup_system "$@"
