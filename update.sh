#!/usr/bin/env bash

set -euo pipefail

DEBUG=${DEBUG:-false}

# Load shared logging and utility functions
source "$(dirname "$0")/install.sh"

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

  log_debug "exiting update_all($(join_args "$@"))"
}

update_all "$@"
