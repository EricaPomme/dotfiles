# ~/dotfiles/shell/completions.zsh
# Unified completion system for CLI tools

### Core -----------------------------------------------------------------------
## Configuration
# Standard completion directory
COMPLETION_DIR="${HOME}/.local/share/zsh/completions"
[[ ! -d "$COMPLETION_DIR" ]] && mkdir -p "$COMPLETION_DIR"

# Add to FPATH if not already present
if [[ ! "$FPATH" =~ "$COMPLETION_DIR" ]]; then
    export FPATH="$COMPLETION_DIR:$FPATH"
fi

## Functions
# Generate/update completions for a tool
_update_completion() {
    local tool="$1"
    local completion_cmd="$2"
    local completion_file="$COMPLETION_DIR/_$tool"
    
    # Skip if tool not available
    command -v "$tool" > /dev/null 2>&1 || return
    
    # Generate if missing or older than 30 days
    if [[ ! -f "$completion_file" ]]; then
        if eval "$completion_cmd" >| "$completion_file" 2>/dev/null; then
            [[ $DEBUG == true ]] && echo "Generated $tool completions" >&2
        fi
    elif [[ -n "$(find "$completion_file" -mtime +30 2>/dev/null)" ]]; then
        if eval "$completion_cmd" >| "$completion_file" 2>/dev/null; then
            [[ $DEBUG == true ]] && echo "Refreshed $tool completions" >&2
        fi
    fi
}

### Tools ----------------------------------------------------------------------
## Completion Generation
# Cross-platform approach: Generate completions for all tools to ensure portability
# across macOS (Homebrew), Linux (package managers), and BSD systems

# Container & Orchestration
_update_completion "docker" "docker completion zsh"
_update_completion "kubectl" "kubectl completion zsh"

# Version Control & GitHub
_update_completion "gh" "gh completion -s zsh"
# Note: git completions are complex and handled well by system packages

# Python Ecosystem
_update_completion "pip" "pip3 completion --zsh"
_update_completion "pip3" "pip3 completion --zsh"

# Rust Ecosystem
_update_completion "rustup" "rustup completions zsh"
# Note: cargo has built-in completion but may not be auto-installed on all systems

# Modern CLI Tools
_update_completion "bat" "bat --completion zsh"
_update_completion "rg" "rg --generate=complete-zsh"
_update_completion "codex" "codex completion zsh"
# Note: fd doesn't support completion generation - relies on system packages

# Package Managers (require user setup)
# _update_completion "npm" "npm completion"        # Requires: npm completion >> ~/.npmrc
# _update_completion "pnpm" "pnpm completion zsh"  # Requires: pnpm setup first
# _update_completion "yarn" "yarn completions"     # Requires: yarn global add completion

# Platform-specific package managers (system handled)
# _update_completion "brew" "brew completion zsh"  # macOS only, complex built-in system
# _update_completion "apt" "_apt"                  # Linux only, handled by system packages
# _update_completion "pacman" "_pacman"            # Arch Linux only, system packages
# _update_completion "pkg" "_pkg"                  # BSD only, system packages

### Shell ----------------------------------------------------------------------
## Completion System
# Initialize completion system
autoload -Uz compinit
compinit -d "${HOME}/.zcompdump"

## Aliases
# Set up kubectl alias completion if available
if command -v kubectl > /dev/null 2>&1 && alias k &>/dev/null; then
    compdef k=kubectl
fi
