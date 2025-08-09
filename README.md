# Dotfiles

These scripts install a minimal environment by linking configuration files and installing packages based on your operating system.

## Supported Platforms

- macOS (Homebrew)
- Debian/Ubuntu (apt)
- Fedora (dnf)
- Arch-based (pacman)  includes Manjaro, EndeavourOS, CachyOS, Garuda, etc.
- **NixOS** (nix-env)

NixOS support is intentionally lightweight. If you manage packages declaratively, you can skip running the package installation step.

Common OS detection logic lives in `util.sh`. It exposes functions such as
`detect_os`, `detect_linux_distro`, and helper predicates like
`is_arch_based` or `is_debian_based` that other scripts source to tailor
behavior for each distribution family.

## Usage

Run `./install.sh` to set up symlinks and install packages for your system. The
script also clones useful git-based tools like **Prezto** and **oh-my-tmux** and
performs their recommended setup steps automatically. Run `./update.sh` to
update installed packages and refresh those git repositories. Use `./cleanup.sh`
to remove old package caches and reclaim disk space.

> **Note**
> The `install.sh` script relies on features specific to **Bash** such as
> `local` variables and parameter expansion like `${VAR,,}`. Ensure that the
> script is executed with `bash` rather than `sh`.

### Environment variables

You can skip parts of the scripts by setting `BYPASS_*` flags before running
them. For example:

```sh
BYPASS_CARGO=true ./install.sh
```

Available flags include `BYPASS_VERIFY_ESSENTIALS`, `BYPASS_GIT_REPOS`,
`BYPASS_OS_PACKAGES`, `BYPASS_CARGO`, `BYPASS_NPM`, `BYPASS_SETUP_DOTFILES`,
`BYPASS_MACOS_DEFAULTS` and `BYPASS_OS_UPDATES`. Setting `DEBUG=true` will
enable verbose logging.

### Git configuration

A global `.gitconfig` lives in `git/gitconfig`. It stores only non-sensitive
defaults such as your name and email. If you need machine-specific settings or
credentials, create `~/.gitconfig.local`; it will be loaded automatically but is
ignored by version control.

