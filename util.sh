#!/usr/bin/env bash

# Default bypass flags shared by the helper scripts
: "${BYPASS_VERIFY_ESSENTIALS:=false}"
: "${BYPASS_GIT_REPOS:=false}"
: "${BYPASS_OS_PACKAGES:=false}"
: "${BYPASS_CARGO:=false}"
: "${BYPASS_NPM:=false}"
: "${BYPASS_SETUP_DOTFILES:=false}"
: "${BYPASS_MACOS_DEFAULTS:=false}"
: "${BYPASS_OS_UPDATES:=false}"

# Logging helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GREY='\033[0;37m'
MAGENTA='\033[0;35m'
RESET='\033[0m'

log_info() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${CYAN}[INFO]${RESET} $1"
}

log_debug() {
    if [ "${DEBUG:-false}" = true ]; then
        echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${BLUE}[DEBUG]${RESET} $1" >&2
    fi
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

join_args() {
    joined=""
    for arg in "$@"; do
        joined="$joined$arg, "
    done
    echo "${joined%, }"
}

# Detect the operating system
# Sets global OS variable to linux, macos or unknown

detect_os() {
    case "$(uname -s)" in
        Linux*) OS="linux" ;;
        Darwin*) OS="macos" ;;
        *) OS="unknown" ;;
    esac
    echo "$OS"
}

# Detect the Linux distribution via /etc/os-release
# Sets global DISTRO_ID

detect_linux_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        # Use tr for lowercase conversion (portable across shells)
        DISTRO_ID="$(echo "$ID" | tr '[:upper:]' '[:lower:]')"
    else
        DISTRO_ID="unknown"
    fi
    echo "$DISTRO_ID"
}

# Map $DISTRO_ID to a higher level family name
# Result stored in DISTRO_FAMILY and also echoed

distro_family() {
    [ -z "${DISTRO_ID:-}" ] && detect_linux_distro >/dev/null
    case "$DISTRO_ID" in
        ubuntu|debian)
            DISTRO_FAMILY="debian"
            ;;
        fedora)
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
            ;;
    esac
    echo "$DISTRO_FAMILY"
}

is_arch_based() { [ "$(distro_family)" = "arch" ]; }

is_debian_based() { [ "$(distro_family)" = "debian" ]; }

is_fedora_based() { [ "$(distro_family)" = "fedora" ]; }

is_nixos() { [ "$(distro_family)" = "nixos" ]; }

