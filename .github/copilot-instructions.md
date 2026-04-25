# Repository Copilot Instructions

## Table of Contents

- [Build, test, and lint commands](#build-test-and-lint-commands)
- [Architecture overview](#architecture-overview)
- [Key conventions](#key-conventions)

## Build, test, and lint commands

There is no build step and no dedicated automated test suite in this repo. Use
the actual entrypoints and script checks below.

```sh
# Preview manifest-driven changes without touching $HOME
./setup.sh --dry-run

# Apply the manifest in dotfiles.conf
./setup.sh

# Apply a different manifest with the same installer
./setup.sh --manifest path/to/manifest.conf

# Install packages from the tracked package lists for the current machine
./packages.sh

# Repo-wide script checks
sh -n setup.sh
bash -n packages.sh
bash -n scripts/split-taggedblocks.sh
python3 -m py_compile scripts/ollama.ask.py scripts/ollama.task2todo.py

# Single-file checks
bash -n packages.sh
python3 -m py_compile scripts/ollama.ask.py

# Markdown linting
markdownlint README.md .github/copilot-instructions.md
```

## Architecture overview

- `dotfiles.conf` is the declarative manifest. Each row is
  `category|mode|noclobber|chmod|user|group|source|target`.
- `setup.sh` is the portable installer. It detects `mac`, `linux`, or `bsd`,
  expands `~`, and executes `link`, `copy`, `newfile`, and `newdir` actions.
  Existing targets are timestamp-backed up before replacement unless
  `noclobber=1`.
- The shell configuration is split into OS-specific entrypoints
  (`shell/zprofile_*`, `shell/zshrc_*`, `shell/zlogin_*`, `shell/zlogout_*`)
  plus reusable helpers under `shell/*.zsh`. The manifest links the
  OS-specific files into `$HOME`, and those entrypoints source the shared
  helpers.
- `packages.sh` is separate from dotfile deployment. It reads the package list
  files (`packages.homebrew*.txt`, `packages.cargo.txt`, `packages.npm.txt`,
  distro-specific lists, and `packages.flatpak.txt`) and installs whatever is
  relevant on the current machine.
- `helix/`, `git/`, `tmux/`, `hammerspoon/`, `ssh/`, and
  `copilot-instructions/` are payload directories consumed by the manifest. If
  a config needs a new destination or a different mode, update `dotfiles.conf`
  together with the payload.

## Key conventions

- Edit repo-backed sources, not the generated files in `$HOME`. After changes,
  use `./setup.sh --dry-run` or `./setup.sh` to apply them.
- Respect the interpreter split: `setup.sh` is POSIX `sh`, `packages.sh` and
  `scripts/split-taggedblocks.sh` are Bash, and the interactive modules under
  `shell/*.zsh` rely on Zsh features. Do not introduce bashisms into
  `setup.sh`.
- New interactive shell behavior usually belongs in a small `shell/*.zsh`
  helper plus an entry in the `includes` array in `shell/zshrc_macos` and/or
  `shell/zshrc_linux`. Reuse the existing `shell/*` and `home/*` path tagging
  convention used by those arrays.
- Machine-local or sensitive settings live outside versioned files:
  `~/.zprofile.local`, `~/.zshrc.local`, `~/.gitconfig.local`, and the copied
  `~/.ssh/config` derived from `ssh/config_template`. The repo intentionally
  ignores `*.local`, `.git-credentials`, `ssh/config`, and
  `.github/copilot-instructions.md`.
- Formatting and editor behavior are centralized in `editorconfig` and
  `helix/languages.toml`. If a change depends on formatting or language-tool
  behavior, update those shared configs instead of adding one-off logic
  elsewhere.
