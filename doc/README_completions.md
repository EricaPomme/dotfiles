# Shell Completion System

## Overview
This directory contains a unified, cross-platform completion system that automatically generates and maintains zsh completions for various CLI tools. Designed to work consistently across macOS, Linux, and BSD systems without relying on platform-specific package managers.

## Generated Completions
Auto-generated via `completions.zsh` (cross-platform):
- **docker** - Docker CLI completion
- **kubectl** - Kubernetes CLI completion  
- **gh** - GitHub CLI completion
- **pip3** - Python package manager completion
- **rustup** - Rust toolchain manager completion
- **bat** - Better cat with syntax highlighting
- **rg** - ripgrep search tool

## Cross-Platform Design
**Why generate instead of relying on system packages?**
- **Portability**: Works on macOS (Homebrew), Linux (apt/yum/pacman), BSD (pkg)
- **Consistency**: Same completions across all environments
- **Freshness**: Always matches your installed tool version
- **Reliability**: No dependency on system package completion quality

## System Package Completions
These tools rely on system packages (present when available):
- **git** - Complex, well-handled by system packages
- **fd** - No built-in completion generation
- **eza** - No built-in completion generation  
- **cargo** - Available via rustup installation

## Completion Priority
FPATH order (higher = higher priority):
1. `~/.local/share/zsh/completions` (our generated completions)
2. Prezto modules
3. System package completion directories (Homebrew, apt, etc.)

Our generated completions override system versions for consistency.

## Manual Setup Required
These tools support completions but require user intervention:
- **npm** - Requires: `npm completion >> ~/.npmrc`
- **pnpm** - Requires: `pnpm setup` first
- **yarn** - Requires: `yarn global add completion` 

## Maintenance
- Completions auto-update every 30 days
- Only generates completions for installed tools
- Gracefully handles missing tools
- Debug mode available via `DEBUG=true`

## File Structure
```
~/.local/share/zsh/completions/
 _bat         # bat (better cat) completion
 _docker      # Docker CLI completion
 _gh          # GitHub CLI completion  
 _kubectl     # Kubernetes CLI completion
 _pip3        # pip3 completion
 _rg          # ripgrep completion
 _rustup      # Rust toolchain completion
```
