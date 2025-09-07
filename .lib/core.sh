#!/usr/bin/env bash

# Core utilities module for dotfiles setup system
# Provides logging, OS detection, bypass flags, and common utilities

#==============================================================================
# Global Variables
#==============================================================================

# Colors for logging
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly GREY='\033[0;37m'
readonly RESET='\033[0m'

# Global state
DEBUG="${DEBUG:-false}"
OS=""
DISTRO_ID=""
DISTRO_FAMILY=""

#==============================================================================
# Bypass Flags (with defaults)
#==============================================================================

: "${BYPASS_VERIFY_ESSENTIALS:=false}"
: "${BYPASS_GIT_REPOS:=false}"
: "${BYPASS_OS_PACKAGES:=false}"
: "${BYPASS_CARGO:=false}"
: "${BYPASS_NPM:=false}"
: "${BYPASS_SETUP_DOTFILES:=false}"
: "${BYPASS_MACOS_DEFAULTS:=false}"
: "${BYPASS_OS_UPDATES:=false}"

#==============================================================================
# Logging Functions
#==============================================================================

log_info() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${CYAN}[INFO]${RESET} $1"
}

log_success() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${GREEN}[SUCCESS]${RESET} $1"
}

log_warning() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}[WARNING]${RESET} $1"
}

log_error() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${RED}[ERROR]${RESET} $1" >&2
}

log_critical() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${MAGENTA}[CRITICAL]${RESET} $1" >&2
    exit 1
}

log_debug() {
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${BLUE}[DEBUG]${RESET} $1" >&2
    fi
}

#==============================================================================
# Utility Functions
#==============================================================================

# Join arguments with commas for debug logging
join_args() {
    local joined=""
    for arg in "$@"; do
        joined="$joined$arg, "
    done
    echo "${joined%, }"
}

# Check if a command is available
command_exists() {
    log_debug "checking if command '$1' exists"
    command -v "$1" >/dev/null 2>&1
}

# Check if a command exists and exit with error if not
require_command() {
    if ! command_exists "$1"; then
        log_critical "Required command '$1' not found. Please install it."
    fi
    log_debug "command '$1' is available"
}

#==============================================================================
# OS Detection
#==============================================================================

# Detect the operating system
detect_os() {
    log_debug "detecting operating system"
    
    case "$(uname -s)" in
        Linux*)
            OS="linux"
            detect_linux_distro
            ;;
        Darwin*)
            OS="macos"
            DISTRO_ID="macos"
            DISTRO_FAMILY="macos"
            ;;
        *)
            OS="unknown"
            DISTRO_ID="unknown"
            DISTRO_FAMILY="unknown"
            log_warning "Unknown operating system: $(uname -s)"
            ;;
    esac
    
    log_debug "OS detected: $OS (distro: $DISTRO_ID, family: $DISTRO_FAMILY)"
}

# Detect Linux distribution
detect_linux_distro() {
    log_debug "detecting Linux distribution"
    
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        DISTRO_ID="${ID,,}" # Convert to lowercase
    else
        DISTRO_ID="unknown"
        log_warning "Cannot detect Linux distribution - /etc/os-release not found"
    fi
    
    # Map distribution to family
    case "$DISTRO_ID" in
        ubuntu|debian)
            DISTRO_FAMILY="debian"
            ;;
        fedora|centos|rhel)
            DISTRO_FAMILY="fedora"
            ;;
        arch|manjaro|endeavouros|cachyos|garuda)
            DISTRO_FAMILY="arch"
            ;;
        nixos)
            DISTRO_FAMILY="nixos"
            ;;
        *)
            DISTRO_FAMILY="unknown"
            log_warning "Unknown Linux distribution family for: $DISTRO_ID"
            ;;
    esac
}

#==============================================================================
# Helper Functions for Distribution Families
#==============================================================================

is_arch_based() { [[ "$DISTRO_FAMILY" == "arch" ]]; }
is_debian_based() { [[ "$DISTRO_FAMILY" == "debian" ]]; }
is_fedora_based() { [[ "$DISTRO_FAMILY" == "fedora" ]]; }
is_nixos() { [[ "$DISTRO_FAMILY" == "nixos" ]]; }
is_macos() { [[ "$OS" == "macos" ]]; }
is_linux() { [[ "$OS" == "linux" ]]; }

#==============================================================================
# Bypass Flag Helpers
#==============================================================================

# Print all bypass flags for debugging
print_bypass_flags() {
    log_debug "Current bypass flags:"
    log_debug "  BYPASS_VERIFY_ESSENTIALS=$BYPASS_VERIFY_ESSENTIALS"
    log_debug "  BYPASS_GIT_REPOS=$BYPASS_GIT_REPOS"
    log_debug "  BYPASS_OS_PACKAGES=$BYPASS_OS_PACKAGES"
    log_debug "  BYPASS_CARGO=$BYPASS_CARGO"
    log_debug "  BYPASS_NPM=$BYPASS_NPM"
    log_debug "  BYPASS_SETUP_DOTFILES=$BYPASS_SETUP_DOTFILES"
    log_debug "  BYPASS_MACOS_DEFAULTS=$BYPASS_MACOS_DEFAULTS"
    log_debug "  BYPASS_OS_UPDATES=$BYPASS_OS_UPDATES"
}

# Check if we should skip a particular operation
should_skip() {
    local operation="$1"
    local bypass_var="BYPASS_$(echo "$operation" | tr '[:lower:]' '[:upper:]')"
    local bypass_value
    
    # Use eval for indirect variable access (bash 3.2 compatible)
    eval "bypass_value=\${$bypass_var:-false}"
    
    if [[ "$bypass_value" == "true" ]]; then
        log_info "Skipping $operation (${bypass_var}=true)"
        return 0
    fi
    
    return 1
}

#==============================================================================
# Initialization
#==============================================================================

# Initialize core module - call this first
core_init() {
    log_debug "initializing core module"
    detect_os
    if [[ "$DEBUG" == "true" ]]; then
        print_bypass_flags
    fi
    log_debug "core module initialized"
}
