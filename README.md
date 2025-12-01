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

You can either run each manager manually as shown below, or use the shortcut script:

```sh
./packages.sh
```

```sh
# Homebrew
brew install $(cat packages.homebrew.txt | sed 's/#.*$//g')
brew install --cask $(cat packages.homebrew-cask.txt | sed 's/#.*$//g')

# Cargo
cargo install $(cat packages.cargo.txt | sed 's/#.*$//g')

# npm (global)
npm install -g $(cat packages.npm.txt | sed 's/#.*$//g')

# Flatpak
flatpak install -y $(cat packages.flatpak.txt | sed 's/#.*$//g')

# Distro-specific
sudo apt install -y $(cat packages.debian.txt | sed 's/#.*$//g')
sudo dnf install -y $(cat packages.fedora.txt | sed 's/#.*$//g')
sudo pacman -S --needed $(cat packages.archlinux.txt | sed 's/#.*$//g')
```

## Core tools (cross-platform baseline)

Regardless of machine, you probably want:
- **Rust** and **cargo** (rustup.rs)
- **Node.js** and **npm** (nodejs.org or your package manager)
