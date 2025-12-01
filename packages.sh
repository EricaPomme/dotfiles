#!/usr/bin/env bash

set -e

# Strip comments from package list files
strip_comments() {
    sed 's/#.*$//g' "$1" | grep -v '^[[:space:]]*$'
}

echo -e "\033[0;32mInstalling packages from package lists...\033[0m"

# Homebrew (macOS)
if command -v brew &> /dev/null; then
    echo -e "\033[0;36mInstalling Homebrew packages...\033[0m"
    if [ -f packages.homebrew.txt ]; then
        brew install $(strip_comments packages.homebrew.txt)
    fi
    
    echo -e "\033[0;36mInstalling Homebrew casks...\033[0m"
    if [ -f packages.homebrew-cask.txt ]; then
        brew install --cask $(strip_comments packages.homebrew-cask.txt)
    fi
fi

# Cargo (Rust)
if command -v cargo &> \/dev\/null; then
    echo -e "\033[0;36mInstalling Cargo packages...\033[0m"
    if [ -f packages.cargo.txt ]; then
        cargo install $(strip_comments packages.cargo.txt)
    fi
fi

# npm (Node.js)
if command -v npm &> /dev/null; then
    echo -e "\033[0;36mInstalling npm global packages...\033[0m"
    if [ -f packages.npm.txt ]; then
        npm install -g $(strip_comments packages.npm.txt)
    fi
fi

# Flatpak
if command -v flatpak &> /dev/null; then
    echo -e "\033[0;36mInstalling Flatpak packages...\033[0m"
    if [ -f packages.flatpak.txt ]; then
        flatpak install -y $(strip_comments packages.flatpak.txt)
    fi
fi

# Debian/Ubuntu (apt)
if command -v apt &> /dev/null; then
    echo -e "\033[0;36mInstalling apt packages...\033[0m"
    if [ -f packages.debian.txt ]; then
        sudo apt install -y $(strip_comments packages.debian.txt)
    fi
fi

# Fedora (dnf)
if command -v dnf &> /dev/null; then
    echo -e "\033[0;36mInstalling dnf packages...\033[0m"
    if [ -f packages.fedora.txt ]; then
        sudo dnf install -y $(strip_comments packages.fedora.txt)
    fi
fi

# Arch Linux (pacman)
if command -v pacman &> /dev/null; then
    echo -e "\033[0;36mInstalling pacman packages...\033[0m"
    if [ -f packages.archlinux.txt ]; then
        sudo pacman -S --needed $(strip_comments packages.archlinux.txt)
    fi
fi
