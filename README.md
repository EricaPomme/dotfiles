# Dotfiles

These scripts install a minimal environment by linking configuration files and installing packages based on your operating system.

## Supported Platforms

- macOS (Homebrew)
- Debian/Ubuntu (apt)
- Fedora (dnf)
- Arch-based (pacman)
- **NixOS** (nix-env)

NixOS support is intentionally lightweight. If you manage packages declaratively, you can skip running the package installation step.

## Usage

Run `./install.sh` to set up symlinks and install packages for your system. The
script also clones useful git-based tools like **Prezto** and **oh-my-tmux** and
performs their recommended setup steps automatically. Run `./update.sh` to
update installed packages.

