#!/usr/bin/env bash

set -euo pipefail

DEBUG=${DEBUG:-false}

# Load shared logging and utility functions
source "$(dirname "$0")/util.sh"

# Initialize bypass flags from util.sh defaults
source_bypass_defaults() {
    : "${BYPASS_VERIFY_ESSENTIALS:=false}"
    : "${BYPASS_GIT_REPOS:=false}"
    : "${BYPASS_OS_PACKAGES:=false}"
    : "${BYPASS_CARGO:=false}"
    : "${BYPASS_NPM:=false}"
    : "${BYPASS_SETUP_DOTFILES:=false}"
    : "${BYPASS_MACOS_DEFAULTS:=false}"
    : "${BYPASS_OS_UPDATES:=false}"
}

# Pull updates for any git-based tools installed by install.sh
update_git_repos() {
  log_debug "entering update_git_repos($(join_args "$@"))"

  if [ -d "$HOME/.zprezto" ]; then
    log_info "Updating Prezto..."
    git -C "$HOME/.zprezto" pull --ff-only \
      || log_warning "Failed to update Prezto"
  else
    log_debug "Prezto not installed"
  fi

  if [ -d "$HOME/.tmux" ]; then
    log_info "Updating oh-my-tmux..."
    git -C "$HOME/.tmux" pull --ff-only \
      || log_warning "Failed to update oh-my-tmux"
  else
    log_debug "oh-my-tmux not installed"
  fi

  log_debug "exiting update_git_repos($(join_args "$@"))"
}

# Check if cargo-update is installed and install if needed
ensure_cargo_update() {
  log_debug "entering ensure_cargo_update($(join_args "$@"))"
  
  if ! command -v cargo &>/dev/null; then
    log_warning "Cargo not available, skipping cargo-update check"
    return 1
  fi
  
  if ! cargo install --list | grep -q "^cargo-update v"; then
    log_info "Installing cargo-update..."
    cargo install cargo-update || {
      log_warning "Failed to install cargo-update"
      return 1
    }
  fi
  
  log_debug "exiting ensure_cargo_update($(join_args "$@"))"
  return 0
}

function update_all() {
  log_debug "entering update_all($(join_args "$@"))"

  # Initialize bypass flags first
  source_bypass_defaults
  
  detect_os

  if ! $BYPASS_OS_UPDATES; then
    # Update package managers
    if [ "$OS" = "macos" ]; then
      if command -v brew &>/dev/null; then
        log_info "Updating Homebrew..."
        brew update && brew upgrade || log_warning "Homebrew update failed"
      fi

      if command -v softwareupdate &>/dev/null; then
        log_info "Applying Apple system updates (softwareupdate)..."
        sudo softwareupdate --all --install --force || log_warning "Apple softwareupdate failed"
      fi
    elif [ "$OS" = "linux" ]; then
      detect_linux_distro
      case "$(distro_family)" in
        debian)
          if command -v apt-get &>/dev/null; then
            log_info "Updating APT..."
            sudo apt-get update && sudo apt-get upgrade -y || log_warning "APT update failed"
          fi
          ;;
        fedora)
          if command -v dnf &>/dev/null; then
            log_info "Updating DNF..."
            sudo dnf upgrade -y || log_warning "DNF update failed"
          fi
          ;;
        arch)
          if command -v pacman &>/dev/null; then
            log_info "Updating Pacman..."
            sudo pacman -Syu --noconfirm || log_warning "Pacman update failed"
          fi
          ;;
        nixos)
          if command -v nix-env &>/dev/null; then
            log_info "Updating Nix packages..."
            nix-env --upgrade || log_warning "Nix update failed"
          fi
          ;;
      esac

      # Update Flatpak if available
      if command -v flatpak &>/dev/null; then
        log_info "Updating Flatpak packages..."
        flatpak update -y || log_warning "Flatpak update failed"
      fi
    fi
  else
    log_info "BYPASS_OS_UPDATES is true, skipping OS package updates"
  fi

  # Update cargo packages
  if ! $BYPASS_CARGO && ensure_cargo_update; then
    log_info "Updating Cargo packages..."
    cargo install-update -a || log_warning "Cargo update failed"
  elif $BYPASS_CARGO; then
    log_info "BYPASS_CARGO is true, skipping Cargo update"
  fi

  # Update npm packages
  if ! $BYPASS_NPM && command -v npm &>/dev/null; then
    log_info "Updating global NPM packages..."
    npm update -g || log_warning "NPM update failed"
  elif $BYPASS_NPM; then
    log_info "BYPASS_NPM is true, skipping NPM update"
  fi

  if ! $BYPASS_GIT_REPOS; then
    update_git_repos
  else
    log_info "BYPASS_GIT_REPOS is true, skipping update_git_repos"
  fi

  log_debug "exiting update_all($(join_args "$@"))"
}

update_all "$@"
