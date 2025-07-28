#!/usr/bin/env bash

set -eu

DEBUG=${DEBUG:-false}

# Load common helpers
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
}

# Check if a command is available in the system's PATH
check_command() {
    log_debug "entering check_command($(join_args "$@"))"
    if ! command -v "$1" &>/dev/null; then
        log_critical "Required command '$1' not found. Please install it."
    fi
    log_debug "exiting check_command($(join_args "$@"))"
}

# Check if a package list file exists
check_packagelist() {
    log_debug "entering check_packagelist($(join_args "$@"))"
    if [ ! -f "$1" ]; then
        log_warning "Package list file '$1' not found, skipping"
        log_debug "exiting check_packagelist($(join_args "$@")) - file not found"
        return 1
    fi
    log_debug "exiting check_packagelist($(join_args "$@")) - file exists"
    return 0
}

# Reads and processes a package list file
read_packagelist() {
    log_debug "entering read_packagelist($(join_args "$@"))"
    grep -vE '^\s*#' "$1" | awk '{print $1}'
    log_debug "exiting read_packagelist($(join_args "$@"))"
}

# Installs packages from predefined package lists based on the detected OS
install_packages() {
    log_debug "entering install_packages($(join_args "$@"))"

    if ! $BYPASS_OS_PACKAGES; then
        if [ "$OS" = "macos" ]; then
            log_debug "installing macOS packages"
            if check_packagelist "packagelists/homebrew.packages"; then
                check_command brew
                log_info "Installing Homebrew packages..."
                read_packagelist "packagelists/homebrew.packages" | xargs brew install || log_warning "Some brew installs may have failed"
            fi
            if check_packagelist "packagelists/homebrew.casks"; then
                check_command brew
                log_info "Installing Homebrew casks..."
                read_packagelist "packagelists/homebrew.casks" | xargs brew install --cask || log_warning "Some cask installs may have failed"
            fi
        elif [ "$OS" = "linux" ]; then
            log_debug "installing Linux packages"
            detect_linux_distro
            case "$(distro_family)" in
            debian)
                if check_packagelist "packagelists/deb.packages"; then
                    check_command apt
                    log_info "Installing APT packages..."
                    sudo apt-get update
                    read_packagelist "packagelists/deb.packages" | xargs sudo apt-get install -y || log_warning "Some apt installs may have failed"
                fi
                ;;
            fedora)
                if check_packagelist "packagelists/fedora.packages"; then
                    check_command dnf
                    log_info "Installing DNF packages..."
                    read_packagelist "packagelists/fedora.packages" | xargs sudo dnf install -y || log_warning "Some dnf installs may have failed"
                fi
                ;;
            arch)
                if check_packagelist "packagelists/pacman.packages"; then
                    check_command pacman
                    log_info "Installing Pacman packages..."
                    read_packagelist "packagelists/pacman.packages" | xargs -r sudo pacman -S --noconfirm --needed || log_warning "Some pacman installs may have failed"
                fi
                ;;
            nixos)
                if check_packagelist "packagelists/nix.packages"; then
                    check_command nix-env
                    log_info "Installing Nix packages..."
                    read_packagelist "packagelists/nix.packages" | xargs nix-env -iA nixos || log_warning "Some nix installs may have failed"
                fi
                ;;
            *)
                log_warning "Unsupported Linux distribution: $DISTRO_ID"
                ;;
            esac

            if command -v flatpak &>/dev/null && check_packagelist "packagelists/flatpak.packages"; then
                log_info "Installing Flatpak packages..."
                read_packagelist "packagelists/flatpak.packages" | xargs -I{} flatpak install -y --noninteractive flathub {} || log_warning "Some flatpak installs may have failed"
            fi
        fi
    else
        log_info "BYPASS_OS_PACKAGES is true, skipping OS package installation"
    fi

    log_debug "installing platform-agnostic packages"
    if ! $BYPASS_CARGO && check_packagelist "packagelists/cargo.packages"; then
        check_command cargo
        log_info "Installing Cargo packages..."
        read_packagelist "packagelists/cargo.packages" | xargs cargo install || log_warning "Some cargo installs may have failed"
    elif $BYPASS_CARGO; then
        log_info "BYPASS_CARGO is true, skipping Cargo packages"
    fi

    if ! $BYPASS_NPM && check_packagelist "packagelists/npm.packages"; then
        check_command npm
        log_info "Installing NPM global packages..."
        read_packagelist "packagelists/npm.packages" | xargs npm install -g || log_warning "Some npm installs may have failed"
    elif $BYPASS_NPM; then
        log_info "BYPASS_NPM is true, skipping NPM packages"
    fi

    log_debug "exiting install_packages($(join_args "$@"))"
}

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

    # OS-specific zshrc selection and symlink configuration
    if [ "$OS" = "macos" ]; then
        ZSHRC_SOURCE="shell/zshrc_macos"
        ZPROFILE_SOURCE="shell/zprofile_macos"
        OS_SPECIFIC_SYMLINKS="hammerspoon|${HOME}/.hammerspoon"
    elif [ "$OS" = "linux" ]; then
        ZSHRC_SOURCE="shell/zshrc_linux"
        ZPROFILE_SOURCE="shell/zprofile_linux"
        OS_SPECIFIC_SYMLINKS=""
    else
        log_warning "Unknown OS: $OS, defaulting to Linux zshrc"
        ZSHRC_SOURCE="shell/zshrc_linux"
        ZPROFILE_SOURCE="shell/zprofile_linux"
        OS_SPECIFIC_SYMLINKS=""
    fi

    # Create symlink pairs - improved error handling
    {
        echo "editorconfig|${HOME}/.editorconfig"
        echo "git/gitconfig|${HOME}/.gitconfig"
        echo "helix|${HOME}/.config/helix"
        echo "nvim/config|${HOME}/.config/nvim"
        echo "shell/p10k.zsh|${HOME}/.p10k.zsh"
        echo "tmux/.tmux.conf.local|${HOME}/.tmux.conf.local"
        if [ -n "$OS_SPECIFIC_SYMLINKS" ]; then
            echo "$OS_SPECIFIC_SYMLINKS"
        fi
        echo "${ZPROFILE_SOURCE}|${HOME}/.zprofile"
        echo "${ZSHRC_SOURCE}|${HOME}/.zshrc"
    } | while IFS="|" read -r src dst; do
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
                backup_file="${dst}.backup.$(date +%Y%m%d%H%M%S)"
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
        if [ -f "ssh/config_template" ]; then
            cp ssh/config_template "$HOME/.ssh/config"
            chmod 600 "$HOME/.ssh/config"
            log_info "SSH config placeholder copied"
        else
            log_warning "SSH config template not found at ssh/config_template"
        fi
    else
        log_info "SSH config already exists at '$HOME/.ssh/config', not overwriting"
    fi

    log_debug "exiting setup_dotfiles($(join_args "$@"))"
}

verify_essentials() {
    log_debug "entering verify_essentials($(join_args "$@"))"

    # Always check these core tools
    check_command git
    check_command zsh
    check_command curl

    # Only check optional tools if they'll be used
    if ! $BYPASS_CARGO && (check_packagelist "packagelists/cargo.packages" 2>/dev/null); then
        check_command cargo
    fi

    if ! $BYPASS_NPM && (check_packagelist "packagelists/npm.packages" 2>/dev/null); then
        check_command npm
    fi

    # OS-specific checks
    if [ "$OS" = "macos" ] && ! $BYPASS_OS_PACKAGES; then
        check_command brew
    fi

    if [ "$OS" = "linux" ] && ! $BYPASS_OS_PACKAGES; then
        # Only check flatpak if we have flatpak packages to install
        if check_packagelist "packagelists/flatpak.packages" 2>/dev/null; then
            check_command flatpak
        fi
    fi

    # Set up zsh as default shell
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

install_git_repos() {
    log_debug "entering install_git_repos($(join_args "$@"))"

    if [ ! -d "$HOME/.zprezto" ]; then
        log_info "Cloning Prezto..."
        git clone --recursive https://github.com/sorin-ionescu/prezto.git "$HOME/.zprezto" ||
            log_warning "Failed to clone Prezto"
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
        git clone https://github.com/gpakosz/.tmux.git "$HOME/.tmux" ||
            log_warning "Failed to clone oh-my-tmux"
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

    log_debug "exiting set_macos_defaults($(join_args "$@"))"
    return 0
}

main() {
    log_debug "entering main($(join_args "$@"))"

    # Initialize bypass flags first
    source_bypass_defaults

    # Important groundwork
    cd "$(dirname "$0")" || exit 1
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
