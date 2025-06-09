#!/usr/bin/env bash

set -euo pipefail

DEBUG=${DEBUG:-false}

# Load shared logging and utility functions
source "$(dirname "$0")/install.sh"

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

function update_all() {
  log_debug "entering update_all($(join_args "$@"))"

  detect_os

  # Update package managers
  case "$OS" in
    macos)
      if command -v brew &>/dev/null; then
        log_info "Updating Homebrew..."
        brew update && brew upgrade || log_warning "Homebrew update failed"
      fi
      ;;
    linux)
      detect_linux_distro
      case "$DISTRO_ID" in
        ubuntu | debian)
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
        arch | endeavouros | cachyos | garuda)
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
      ;;
  esac

  # Update cargo packages
  if command -v cargo &>/dev/null; then
    log_info "Updating Cargo packages..."
    cargo install-update -a || log_warning "Cargo update failed"
  fi

  # Update npm packages
  if command -v npm &>/dev/null; then
    log_info "Updating global NPM packages..."
    npm update -g || log_warning "NPM update failed"
  fi

  update_git_repos

  log_debug "exiting update_all($(join_args "$@"))"
}

update_all "$@"
