# Dotfiles

Symlink manager for config files plus package lists.

## Quick start

```sh
./setup.sh --dry-run
./setup.sh
```

Edits `symlinks.conf` (format: `category|source|target`) and reruns the script.

## Package lists

This repo tracks package names for multiple managers:
- `packages.homebrew.txt` / `packages.homebrew-cask.txt` (macOS)
- `packages.cargo.txt` (Rust)
- `packages.npm.txt` (Node)
- `packages.{archlinux,debian,fedora}.txt`, `packages.flatpak.txt` (Linux distros)

### Read in package lists

```sh
# Homebrew
brew install $(cat packages.homebrew.txt)
brew install --cask $(cat packages.homebrew-cask.txt)

# Cargo
cat packages.cargo.txt | xargs cargo install

# npm (global)
npm install -g $(cat packages.npm.txt)

# Flatpak
flatpak install -y $(cat packages.flatpak.txt)

# Distro-specific
sudo apt install -y $(cat packages.debian.txt)
sudo dnf install -y $(cat packages.fedora.txt)
sudo pacman -S --needed $(cat packages.archlinux.txt)
```

## Core tools (cross-platform baseline)

Regardless of machine, you probably want:
- **Rust** and **cargo** (rustup.rs)
- **Node.js** and **npm** (nodejs.org or your package manager)
