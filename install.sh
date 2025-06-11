#!/usr/bin/env bash

set -eu

DEBUG=${DEBUG:-false}

# Bypass controls for major sections
BYPASS_VERIFY_ESSENTIALS=${BYPASS_VERIFY_ESSENTIALS:-false}
BYPASS_GIT_REPOS=${BYPASS_GIT_REPOS:-false}
BYPASS_OS_PACKAGES=${BYPASS_OS_PACKAGES:-false}
BYPASS_CARGO=${BYPASS_CARGO:-false}
BYPASS_NPM=${BYPASS_NPM:-false}
BYPASS_SETUP_DOTFILES=${BYPASS_SETUP_DOTFILES:-false}
BYPASS_MACOS_DEFAULTS=${BYPASS_MACOS_DEFAULTS:-false}

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
  if $DEBUG; then
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
  # Remove trailing comma and space
  echo "${joined%, }"
}

# Check if a command is available in the system's PATH
#
# This function verifies if a specified command exists and is executable.
# If the command is not found, it logs a critical error and exits the script.
#
# Arguments:
#   $1 - The command name to check for availability
#
# Returns:
#   0 - If the command exists and is executable
#   Does not return if command is not found (exits with error)
check_command() {
  log_debug "entering check_command($(join_args "$@"))"
  if ! command -v "$1" &>/dev/null; then
    log_critical "Required command '$1' not found. Please install it."
  fi
  log_debug "exiting check_command($(join_args "$@"))"
}

# Detects the operating system of the current environment
#
# This function determines whether the script is running on Linux or macOS
# by examining the output of 'uname -s'. It sets the global variable OS
# to either "linux" or "macos" accordingly. If an unrecognized operating
# system is detected, the global variable OS will be set to "unknown" and
# the script will continue with limited functionality.
#
# Arguments:
#   None
#
# Returns:
#   None - Sets the global variable OS to the detected operating system
#           (or "unknown" if unrecognized)
detect_os() {
  log_debug "entering detect_os($(join_args "$@"))"
  case "$(uname -s)" in
    Linux*) OS="linux" ;;
    Darwin*) OS="macos" ;;
    *)
      OS="unknown"
      log_warning "Unrecognized OS: $(uname -s). Some features will be skipped."
      ;;
  esac
  log_info "Detected OS: $OS"
  log_debug "exiting detect_os($(join_args "$@"))"
}

# Detects the Linux distribution of the current environment
#
# This function determines the specific Linux distribution by sourcing
# the /etc/os-release file, which contains distribution identification data.
# It sets the global variable DISTRO_ID to the lowercase value of the ID field
# from os-release. If the os-release file is not found, the script will exit
# with an error.
#
# Arguments:
#   None
#
# Returns:
#   None - Sets the global variable DISTRO_ID to the detected Linux distribution
#   Exits with error if the distribution cannot be detected
detect_linux_distro() {
  log_debug "entering detect_linux_distro($(join_args "$@"))"
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID="${ID,,}"
  else
    log_critical "Unable to detect Linux distribution"
  fi
  log_info "Detected Linux distribution: $DISTRO_ID"
  log_debug "exiting detect_linux_distro($(join_args "$@"))"
}

# Reads and processes a package list file
#
# This function reads a package list file, filters out commented lines
# (those starting with #), and returns only the first column of each line.
# This is useful for extracting clean package names from configuration files
# that may contain comments or additional metadata.
#
# Arguments:
#   $1 - Path to the package list file to be processed
#
# Returns:
#   Outputs a list of package names (one per line) to stdout
read_packagelist() {

  log_debug "entering read_packagelist($(join_args "$@"))"
  grep -vE '^\s*#' "$1" | awk '{print $1}'
  log_debug "exiting read_packagelist($(join_args "$@"))"
}

# Installs packages from predefined package lists based on the detected OS
#
# This function handles package installation across different operating systems
# and package managers. It first installs OS-specific packages (Homebrew for macOS,
# apt/dnf for Linux distributions), then proceeds to install platform-agnostic
# packages (Cargo, NPM). The function reads package names from predefined files
# in the packagelists directory and installs them using the appropriate package manager.
#
# Arguments:
#   None - Uses global variables OS and DISTRO_ID set by detect_os and detect_linux_distro
#
# Returns:
#   0 - On successful execution (even if some package installations fail)
#   Package installation failures are logged as warnings but don't cause the function to exit
install_packages() {
  log_debug "entering install_packages($(join_args "$@"))"

  if ! $BYPASS_OS_PACKAGES; then
    case "$OS" in
      macos)
      log_debug "installing macOS packages"
      if [ -f "packagelists/homebrew.packages" ]; then
        check_command brew
        log_info "Installing Homebrew packages..."
        read_packagelist "packagelists/homebrew.packages" | xargs brew install || log_warning "Some brew installs may have failed"
      fi
      if [ -f "packagelists/homebrew.casks" ]; then
        check_command brew
        log_info "Installing Homebrew casks..."
        read_packagelist "packagelists/homebrew.casks" | xargs brew install --cask || log_warning "Some cask installs may have failed"
      fi
      ;;
    linux)
      log_debug "installing Linux packages"
      detect_linux_distro
      case "$DISTRO_ID" in
        ubuntu | debian)
          if [ -f "packagelists/deb.packages" ]; then
            check_command apt
            log_info "Installing APT packages..."
            sudo apt-get update
            read_packagelist "packagelists/deb.packages" | xargs sudo apt-get install -y || log_warning "Some apt installs may have failed"
          fi
          ;;
        fedora)
          if [ -f "packagelists/fedora.packages" ]; then
            check_command dnf
            log_info "Installing DNF packages..."
            read_packagelist "packagelists/fedora.packages" | xargs sudo dnf install -y || log_warning "Some dnf installs may have failed"
          fi
          ;;
        arch | endeavouros | cachyos | garuda)
          if [ -f "packagelists/pacman.packages" ]; then
            check_command pacman
            log_info "Installing Pacman packages..."
            read_packagelist "packagelists/pacman.packages" | xargs -r sudo pacman -S --noconfirm --needed || log_warning "Some pacman installs may have failed"
          fi
          ;;
        nixos)
          if [ -f "packagelists/nix.packages" ]; then
            check_command nix-env
            log_info "Installing Nix packages..."
            read_packagelist "packagelists/nix.packages" | xargs nix-env -iA nixos || log_warning "Some nix installs may have failed"
          fi
          ;;
        *)
          log_warning "Unsupported Linux distribution: $DISTRO_ID"
          ;;
      esac

      if command -v flatpak &>/dev/null && [ -f "packagelists/flatpak" ]; then
        log_info "Installing Flatpak packages..."
        read_packagelist "packagelists/flatpak" | xargs -I{} flatpak install -y --noninteractive flathub {} || log_warning "Some flatpak installs may have failed"
      fi
      ;;
    esac
  else
    log_info "BYPASS_OS_PACKAGES is true, skipping OS package installation"
  fi

  log_debug "installing platform-agnostic packages"
  if ! $BYPASS_CARGO && [ -f "packagelists/cargo" ]; then
    check_command cargo
    log_info "Installing Cargo packages..."
    read_packagelist "packagelists/cargo" | xargs cargo install || log_warning "Some cargo installs may have failed"
  elif $BYPASS_CARGO; then
    log_info "BYPASS_CARGO is true, skipping Cargo packages"
  fi

  if ! $BYPASS_NPM && [ -f "packagelists/npm" ]; then
    check_command npm
    log_info "Installing NPM global packages..."
    read_packagelist "packagelists/npm" | xargs npm install -g || log_warning "Some npm installs may have failed"
  elif $BYPASS_NPM; then
    log_info "BYPASS_NPM is true, skipping NPM packages"
  fi

  log_debug "exiting install_packages($(join_args "$@"))"
}


# Sets up dotfiles by creating symbolic links and configuring SSH
#
# This function creates symbolic links from the dotfiles repository to the
# appropriate locations in the user's home directory. It handles configuration
# files for tmux, zsh, and Hammerspoon. Additionally, it sets up
# an SSH config file if one doesn't already exist.
#
# The function checks if symlinks already exist and are correctly set before
# creating new ones, avoiding unnecessary operations. For the SSH config,
# it will not overwrite an existing file to preserve user customizations.
#
# Arguments:
#   None - Uses the current working directory as the source for dotfiles
#
# Returns:
#   0 - On successful execution
#   All operations are logged with appropriate info messages
setup_dotfiles() {
  log_debug "entering setup_dotfiles($(join_args "$@"))"

  # Ensure HOME and PWD are defined
  if [ -z "${HOME:-}" ]; then
    log_critical "HOME environment variable is not defined"
  fi

  if [ -z "${PWD:-}" ]; then
    PWD="$(pwd)"
    log_warning "PWD was not defined, using current directory: $PWD"
  fi

  # Use a fully POSIX-compliant approach with newline-separated pairs
  # OS-specific zshrc selection and symlink configuration
  case "$OS" in
    macos)
      ZSHRC_SOURCE="shell/zshrc_macos"
      OS_SPECIFIC_SYMLINKS="hammerspoon|${HOME}/.hammerspoon"
      ;;
    linux)
      ZSHRC_SOURCE="shell/zshrc_linux"
      OS_SPECIFIC_SYMLINKS=""
      ;;
    *)
      log_warning "Unknown OS: $OS, defaulting to Linux zshrc"
      ZSHRC_SOURCE="shell/zshrc_linux"
      OS_SPECIFIC_SYMLINKS=""
      ;;
  esac

  symlink_pairs="$(cat <<EOF
# Format: source|destination
nvim/config|${HOME}/.config/nvim
tmux/.tmux.conf.local|${HOME}/.tmux.conf.local
${ZSHRC_SOURCE}|${HOME}/.zshrc
${OS_SPECIFIC_SYMLINKS}
EOF
)"

  echo "${symlink_pairs}" | grep -v "^#" | grep -v "^$" | while IFS="|" read -r src dst; do
    # Skip empty lines
    [ -z "$src" ] && continue
    
    # Ensure source file exists
    if [ ! -e "${PWD}/${src}" ]; then
      log_warning "Source file '${PWD}/${src}' does not exist, skipping symlink creation"
      continue
    fi
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$dst")"
    
    # Check if symlink already exists and points to the correct location
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$PWD/$src" ]; then
      log_info "Symlink for '$dst' already correctly set"
    else
      # Backup existing file if it's not a symlink
      if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        local backup_file="${dst}.backup.$(date +%Y%m%d%H%M%S)"
        log_info "Backing up existing file '$dst' to '$backup_file'"
        mv "$dst" "$backup_file"
      fi
      
      # Create the symlink
      if ln -sf "$PWD/$src" "$dst"; then
        log_info "Updated symlink: $dst → $PWD/$src"
      else
        log_error "Failed to create symlink from '$PWD/$src' to '$dst'"
      fi
    fi
  done

  # SSH config
  mkdir -p "$HOME/.ssh"
  if [ ! -f "$HOME/.ssh/config" ]; then
    cp ssh/config_template "$HOME/.ssh/config"
    chmod 600 "$HOME/.ssh/config"
    log_info "SSH config placeholder copied"
  else
    log_info "SSH config already exists at '$HOME/.ssh/config', not overwriting"
  fi

  log_debug "exiting setup_dotfiles($(join_args "$@"))"
}

# Verifies and sets up essential tools for the environment
#
# This function checks for the presence of required commands (git, zsh, curl)
# and ensures that zsh is set as the default shell for the current user.
# If zsh is not the default shell, it adds the zsh path to /etc/shells if needed
# and attempts to change the user's default shell to zsh.
#
# Arguments:
#   None
#
# Returns:
#   0 - On successful execution
#   Failures in changing the default shell are logged as warnings but don't cause the function to exit
verify_essentials() {
  log_debug "entering verify_essentials($(join_args "$@"))"
  check_command git
  check_command zsh
  check_command curl
  check_command cargo
  [ "$OS" = "macos" ] && check_command brew
  [ "$OS" = "linux" ] && check_command flatpak

  ZSH_PATH=$(command -v zsh)
  if [ "$SHELL" != "$ZSH_PATH" ]; then
    if ! grep -q "$ZSH_PATH" /etc/shells; then
      log_info "Adding '$ZSH_PATH' to /etc/shells"
      echo "$ZSH_PATH" | sudo tee -a /etc/shells
    fi
    log_info "Changing default shell to zsh for user '$USER'"
    chsh -s "$ZSH_PATH" || log_warning "Failed to change default shell"
  fi
  log_debug "exiting verify_essentials($(join_args "$@"))"
}

# Clones git-based tools like Prezto and oh-my-tmux
#
# This function checks if each repository has already been installed in the
# user's home directory. If not, it clones the repository and performs any
# required setup. Progress is reported using the standard logging helpers.
install_git_repos() {
  log_debug "entering install_git_repos($(join_args "$@"))"

  if [ ! -d "$HOME/.zprezto" ]; then
    log_info "Cloning Prezto..."
    git clone --recursive https://github.com/sorin-ionescu/prezto.git "$HOME/.zprezto" \
      || log_warning "Failed to clone Prezto"
    log_info "Linking Prezto runcoms"
    for rcfile in "$HOME"/.zprezto/runcoms/*; do
      [ "$(basename "$rcfile")" = "README.md" ] && continue
      target="$HOME/.${rcfile##*/}"
      if [ -e "$target" ]; then
        log_debug "$target already exists"
      else
        ln -s "$rcfile" "$target"
      fi
    done
  else
    log_info "Prezto already installed"
  fi

  if [ ! -d "$HOME/.tmux" ]; then
    log_info "Cloning oh-my-tmux..."
    git clone https://github.com/gpakosz/.tmux.git "$HOME/.tmux" \
      || log_warning "Failed to clone oh-my-tmux"
    ln -sf "$HOME/.tmux/.tmux.conf" "$HOME/.tmux.conf"
    if [ -e "$HOME/.tmux.conf.local" ]; then
      log_debug "$HOME/.tmux.conf.local already exists"
    else
      ln -s "$PWD/tmux/.tmux.conf.local" "$HOME/.tmux.conf.local"
    fi
  else
    log_info "oh-my-tmux already installed"
  fi

  log_debug "exiting install_git_repos($(join_args "$@"))"
}

# Configures macOS system defaults for improved usability
#
# This function applies a series of macOS-specific system preferences and UI settings
# to enhance the user experience and restarts the necessary system processes to apply
# these changes.
#
# Arguments:
#   None - No parameters are required
#
# Returns:
#   0 - On successful execution
#   All operations are logged with appropriate debug and info messages
#   UI component restarts that fail are logged as warnings but don't cause the function to exit
set_macos_defaults() {
  log_debug "entering set_macos_defaults($(join_args "$@"))"
  log_info "Applying macOS system defaults"

  ### Finder Preferences ###
  log_debug "Showing hidden files in Finder"
  defaults write com.apple.finder AppleShowAllFiles -bool true

  log_debug "Showing status bar in Finder"
  defaults write com.apple.finder ShowStatusBar -bool true

  log_debug "Keeping folders on top when sorting by name"
  defaults write com.apple.finder _FXSortFoldersFirst -bool true
  defaults write NSGlobalDomain AppleShowAllFiles -bool true

  log_debug "Searching current folder by default"
  defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

  log_debug "Disabling extension change warning"
  defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

  ### Dock / Animation ###
  log_debug "Speeding up Mission Control animations"
  defaults write com.apple.dock expose-animation-duration -float 0.1

  ### Safari ###
  log_debug "Attempting to set Safari preferences"
  if defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true 2>/dev/null; then
    log_info "Successfully set Safari preferences"
  else
    log_warning "Failed to set Safari preferences - may require full disk access"
  fi

  ### Refresh UI ###
  log_debug "Restarting Finder and Dock to apply changes"
  killall Finder >/dev/null 2>&1 || log_warning "Finder was not running"
  killall Dock >/dev/null 2>&1 || log_warning "Dock was not running"
  
  # Always return success, even if some settings couldn't be applied
  log_debug "exiting set_macos_defaults($(join_args "$@"))"
  return 0

}

# Main entry point for the script
#
# This function orchestrates the execution of all other functions, ensuring
# that they are executed in the correct order and with the necessary logging.
#
# Arguments:
#   $@ - All command line arguments passed to the script
#
# Returns:
#   0 - On successful execution
main() {
  log_debug "entering main($(join_args "$@"))"

  # Important groundwork
  detect_os

  if [ "$OS" = "unknown" ]; then
    log_warning "Skipping package installation for unknown OS"
    setup_dotfiles
    log_debug "exiting main($(join_args "$@"))"
    return
  fi

  if ! $BYPASS_VERIFY_ESSENTIALS; then
    verify_essentials
  else
    log_info "BYPASS_VERIFY_ESSENTIALS is true, skipping verify_essentials"
  fi

  if ! $BYPASS_GIT_REPOS; then
    install_git_repos
  else
    log_info "BYPASS_GIT_REPOS is true, skipping install_git_repos"
  fi

  if $BYPASS_OS_PACKAGES && $BYPASS_CARGO && $BYPASS_NPM; then
    log_info "All package bypass flags are true, skipping install_packages"
  else
    # Unpack the boxes
    install_packages
  fi

  if ! $BYPASS_SETUP_DOTFILES; then
    setup_dotfiles
  else
    log_info "BYPASS_SETUP_DOTFILES is true, skipping setup_dotfiles"
  fi

  # OS Specific calls
  if [ "$OS" = "macos" ]; then
    if ! $BYPASS_MACOS_DEFAULTS; then
      set_macos_defaults
    else
      log_info "BYPASS_MACOS_DEFAULTS is true, skipping set_macos_defaults"
    fi
  fi

  log_debug "exiting main($(join_args "$@"))"
}

main "$@"
