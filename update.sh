#!/usr/bin/env bash

case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        echo "Windows detected. Run update.ps1 with PowerShell instead." >&2
        exit 0
        ;;
esac

set -euo pipefail

DEBUG=${DEBUG:-false}

# Bypass controls for major sections
BYPASS_OS_UPDATES=${BYPASS_OS_UPDATES:-false}
BYPASS_CARGO=${BYPASS_CARGO:-false}
BYPASS_NPM=${BYPASS_NPM:-false}
BYPASS_GIT_REPOS=${BYPASS_GIT_REPOS:-false}

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

  if ! $BYPASS_OS_UPDATES; then
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
  else
    log_info "BYPASS_OS_UPDATES is true, skipping OS package updates"
  fi

  # Update cargo packages
  if ! $BYPASS_CARGO && command -v cargo &>/dev/null; then
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
