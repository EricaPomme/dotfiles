# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Repository Architecture

### Multi-Platform Dotfiles System
This is a cross-platform dotfiles repository that supports:
- **Linux**: Arch-based (pacman), Debian-based (apt), Fedora (dnf), NixOS (nix-env)
- **macOS**: Homebrew package management
- **Package Managers**: Native OS packages plus Cargo, npm, and Flatpak

### Core Components

#### OS Detection & Abstraction (`util.sh`)
- `detect_os()` sets global `OS` variable (linux/macos/unknown)
- `detect_linux_distro()` sets `DISTRO_ID` from `/etc/os-release`
- `distro_family()` maps distros to families (debian/fedora/arch/nixos)
- Helper predicates: `is_arch_based()`, `is_debian_based()`, etc.

#### Installation System (`install.sh`)
- **Symlink Management**: Creates OS-specific symlinks (`zshrc_linux` vs `zshrc_macos`)
- **Package Installation**: Reads from `packagelists/` directory, one file per package manager
- **Git Repository Setup**: Clones and configures Prezto (ZSH framework) and oh-my-tmux
- **Bypass System**: Environment variables (`BYPASS_*`) to skip installation steps

#### Configuration Structure
```
shell/          # ZSH configurations and aliases
├── zshrc_linux, zshrc_macos    # Platform-specific shells
├── alias_*.zsh                 # Modular alias system
└── prompt.zsh                  # Git-aware prompt with caching

packagelists/   # Package definitions per platform
├── pacman.packages, deb.packages, fedora.packages
├── homebrew.packages, cargo.packages, npm.packages
└── flatpak.packages, nix.packages

helix/          # Primary text editor configuration
├── config.toml                 # LSP, keybindings, UI settings
└── languages.toml

hammerspoon/    # macOS-specific window management
└── init.lua    # F13/F14/F15 layer system, app launchers
```

### Key Development Patterns

#### Platform-Specific Configuration Selection
```bash
# install.sh logic
if [ "$OS" = "macos" ]; then
    ZSHRC_SOURCE="shell/zshrc_macos"
    OS_SPECIFIC_SYMLINKS="hammerspoon|${HOME}/.hammerspoon"
elif [ "$OS" = "linux" ]; then
    ZSHRC_SOURCE="shell/zshrc_linux" 
    OS_SPECIFIC_SYMLINKS=""
fi
```

#### Package List Processing
- Lines starting with `#` are comments and ignored
- `read_packagelist()` filters comments and extracts package names
- Each platform has its own package list file in `packagelists/`

#### Shell Enhancement System
- **Modular Aliases**: Each `alias_*.zsh` file handles specific tool categories
- **Conditional Loading**: Features only load if required commands are available
- **FZF Integration**: Intelligent fallback chain (fd → rg → find)
- **Git Prompt Caching**: 30-second cache for local status, 5-minute cache for upstream

### Important Implementation Details

#### Helix Editor Configuration
- Primary editor with custom keybindings (Ctrl+S save, Ctrl+F format)
- LSP enabled with inlay hints and signature help
- Integrated with ZSH shell for command execution
- Custom alias: `shx` runs helix with sudo using dotfiles config

#### Hammerspoon System (macOS only)
- **Layer Tap System**: F13 (apps), F14 (text macros), F15 (navigation)
- **Modal Timeout**: 200ms threshold for tap vs hold behavior
- **URL Transformation**: Converts social media URLs to privacy-friendly alternatives
- **Debouncing**: 75ms threshold to prevent key repeat issues

#### Backup Strategy
Before modifying any configuration files, the user requires creating timestamped backups:
```bash
cp -- "original" "original.$(date +'%Y%m%d_%H%M%S').comment.backup"
```

#### Git Configuration
- Main config in `git/gitconfig` contains non-sensitive defaults
- Machine-specific settings expected in `~/.gitconfig.local` (not version controlled)
- SSH config templated from `ssh/config_template`

### Development Considerations

When working with this repository:
1. **OS Detection**: Always use `util.sh` functions rather than hardcoding platform checks
2. **Package Lists**: Add new packages to appropriate `packagelists/` file
3. **Shell Features**: New shell enhancements should be modular files in `shell/`
4. **Bypass Flags**: Use `BYPASS_*` environment variables for testing specific components
5. **Cross-Platform**: Consider both Linux and macOS when making changes
6. **Performance**: Git prompt functions use caching to avoid expensive operations

The repository follows a "write code like someone else has to read it on a broken terminal with a hangover" philosophy with robust error handling and clear separation of concerns.

<citations>
<document>
<document_type>RULE</document_type>
<document_id>5XWfZZPdTTKpWfuveMzjAp</document_id>
</document>
<document>
<document_type>RULE</document_type>
<document_id>FGAmqkgTwgCOsRU6VPTNXU</document_id>
</document>
<document>
<document_type>RULE</document_type>
<document_id>XGC60MCYMYK5ang3QfJtw2</document_id>
</document>
</citations>
