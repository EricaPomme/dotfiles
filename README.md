# Dotfiles Setup System v2.0.0

A modular, cross-platform dotfiles management system built for reliability and flexibility.

## Quick Start

```bash
# Full installation
./setup.sh install

# Update everything
./setup.sh update

# Clean package caches
./setup.sh cleanup
```

## System Overview

This dotfiles system is designed around **modularity**, **cross-platform compatibility**, and **selective installation**. Instead of monolithic scripts, it uses a library-based architecture with bypass flags for granular control.

### Key Features

- **🔧 Modular Architecture**: Core functionality split into focused modules
- **🖥️ Cross-Platform Support**: Works on macOS, Linux distributions, and BSD variants
- **📦 Multi-Package Manager Support**: Homebrew, apt, dnf, pacman, Nix, Flatpak, Cargo, NPM
- **🔗 Smart Symlink Management**: Automatic backup and validation of dotfile links
- **⚡ Selective Installation**: Bypass flags to skip specific components
- **🐚 Shell-Agnostic**: Compatible with bash 3.2+ and zsh
- **🛡️ Safe by Default**: Validates tools and creates backups before making changes

## Commands

### `install`
Performs complete system setup:
- Verifies essential tools are available
- Installs OS packages and language-specific packages
- Sets up dotfile symlinks with backup of existing files
- Clones and configures external repositories
- Applies system configurations (macOS defaults, etc.)

### `update`
Updates all managed components:
- Updates OS package managers
- Updates language package managers (Cargo, NPM)
- Pulls latest changes from external git repositories

### `cleanup`
Cleans up cached files:
- Clears package manager caches
- Removes temporary files and old downloads

## Bypass Flags

Use environment variables to skip specific installation steps:

| Flag | Purpose |
|------|---------|
| `BYPASS_VERIFY_ESSENTIALS=true` | Skip essential tool verification |
| `BYPASS_GIT_REPOS=true` | Skip git repository operations |
| `BYPASS_OS_PACKAGES=true` | Skip OS package installation |
| `BYPASS_CARGO=true` | Skip Cargo package installation |
| `BYPASS_NPM=true` | Skip NPM package installation |
| `BYPASS_SETUP_DOTFILES=true` | Skip dotfile symlink setup |
| `BYPASS_MACOS_DEFAULTS=true` | Skip macOS system defaults |
| `BYPASS_OS_UPDATES=true` | Skip OS package updates |

### Examples

```bash
# Install only dotfiles, skip packages
BYPASS_OS_PACKAGES=true BYPASS_CARGO=true BYPASS_NPM=true ./setup.sh install

# Update only git repositories
BYPASS_OS_UPDATES=true ./setup.sh update

# Debug mode with verbose logging
DEBUG=true ./setup.sh install --debug
```

## Directory Structure

```
dotfiles/
├── setup.sh              # Main entry point script
├── .lib/                 # Modular libraries
│   ├── core.sh           # Logging, OS detection, utilities
│   ├── packages.sh       # Package manager handling
│   ├── repos.sh          # Git repository management
│   ├── dotfiles.sh       # Symlink management
│   └── system.sh         # System configuration
├── packagelists/         # Package definitions per manager
│   ├── homebrew          # macOS packages
│   ├── deb               # Debian/Ubuntu packages
│   ├── fedora            # Fedora/RHEL packages
│   ├── pacman            # Arch Linux packages
│   ├── nix               # Nix packages
│   ├── flatpak           # Flatpak applications
│   ├── cargo             # Rust packages
│   └── npm               # Node.js packages
├── shell/                # Shell configurations
│   ├── zshrc_macos       # macOS zsh configuration
│   ├── zprofile_macos    # macOS zsh profile
│   ├── zshrc_linux       # Linux zsh configuration
│   ├── zprofile_linux    # Linux zsh profile
│   ├── p10k.zsh          # Powerlevel10k theme
│   ├── completions.zsh   # Custom completions
│   ├── fzf.zsh           # FZF integration
│   ├── alias_*.zsh       # Modular aliases
│   └── *.zsh             # Various shell utilities
├── git/                  # Git configuration
│   └── gitconfig         # Global git settings
├── helix/                # Helix editor configuration
├── hammerspoon/          # Hammerspoon (macOS automation)
├── tmux/                 # Tmux configuration
│   └── .tmux.conf.local  # Local tmux overrides
├── ssh/                  # SSH configuration templates
└── scripts/              # Utility scripts
```

## Configuration Files

### Package Lists

Each file in `packagelists/` contains one package per line for the respective package manager:

- **homebrew**: macOS packages via Homebrew
- **deb**: Debian/Ubuntu packages via apt
- **fedora**: Fedora/RHEL packages via dnf
- **pacman**: Arch Linux packages via pacman
- **nix**: Nix packages (cross-platform)
- **flatpak**: Flatpak applications (Linux)
- **cargo**: Rust packages via Cargo
- **npm**: Node.js packages via NPM

### Shell Configuration

The system uses OS-specific shell configurations:

- **macOS**: `shell/zshrc_macos` and `shell/zprofile_macos`
- **Linux**: `shell/zshrc_linux` and `shell/zprofile_linux`

Shell utilities are modularly organized:
- `alias_*.zsh`: Categorized aliases (eza, tar, helix, etc.)
- `completions.zsh`: Custom command completions
- `fzf.zsh`: Fuzzy finder integration
- `p10k.zsh`: Powerlevel10k prompt configuration
- `prompt.zsh`: Custom prompt enhancements

### External Repositories

The system manages external git repositories:
- **Prezto**: Zsh framework
- **oh-my-tmux**: Tmux configuration framework

These are cloned to `~/.zprezto` and `~/.tmux` respectively.

## System Requirements

### Essential Tools
- **bash** 3.2+ or **zsh** (for script execution)
- **git** (for repository management)

### Platform-Specific Package Managers
- **macOS**: Homebrew
- **Debian/Ubuntu**: apt
- **Fedora/RHEL**: dnf
- **Arch Linux**: pacman
- **Any Linux**: Nix, Flatpak (optional)

### Language Package Managers
- **Rust**: Cargo (optional)
- **Node.js**: NPM (optional)

## Troubleshooting

### Debug Mode
Enable verbose logging to diagnose issues:
```bash
DEBUG=true ./setup.sh install --debug
```

### Validation
The system includes built-in validation for symlinks and configurations. Check the debug output for warnings about missing files or broken symlinks.

### Path Issues
If commands aren't found during execution, the system automatically sets a default PATH. Check your shell configuration files for PATH modifications.

### Permission Issues
- **macOS**: Some system defaults require admin privileges
- **Linux**: Package installation may require sudo access

## Development

### Architecture

The system follows a modular design:

1. **core.sh**: Foundation module providing logging, OS detection, and utilities
2. **packages.sh**: Handles all package manager operations
3. **repos.sh**: Manages external git repositories
4. **dotfiles.sh**: Creates and validates symlinks
5. **system.sh**: Applies OS-specific system configurations
6. **setup.sh**: Main orchestrator that coordinates all modules

### Adding New Package Managers

1. Add package list file in `packagelists/`
2. Extend `packages.sh` with installation and update functions
3. Add bypass flag support

### Adding New Platforms

1. Extend OS detection in `core.sh`
2. Add platform-specific logic in relevant modules
3. Create platform-specific shell configurations if needed

### Testing

Use bypass flags to test specific components in isolation:

```bash
# Test only symlink creation
BYPASS_VERIFY_ESSENTIALS=true BYPASS_OS_PACKAGES=true BYPASS_CARGO=true BYPASS_NPM=true BYPASS_GIT_REPOS=true BYPASS_MACOS_DEFAULTS=true ./setup.sh install

# Test only package installation
BYPASS_SETUP_DOTFILES=true BYPASS_GIT_REPOS=true BYPASS_MACOS_DEFAULTS=true ./setup.sh install
```

---

## TODO:

### High Priority
- [ ] Fix output interleaving issue in full setup.sh runs (cosmetic debugging issue)
- [ ] Add validation command to setup.sh CLI interface
- [ ] Implement proper error recovery for failed symlink operations

### Medium Priority
- [ ] Add support for Windows PowerShell/WSL environments
- [ ] Extend system.sh with Linux desktop environment configurations (GNOME, KDE)
- [ ] Add BSD-specific package manager support (pkg, ports)
- [ ] Implement rollback functionality for system changes
- [ ] Add configuration file templates for new systems

### Low Priority
- [ ] Implement configuration drift detection
- [ ] Add support for encrypted dotfiles (GPG integration)
- [ ] Create automated testing framework for different OS environments

### Nice to Have
- [ ] Integration with CI/CD for automated testing on commits
