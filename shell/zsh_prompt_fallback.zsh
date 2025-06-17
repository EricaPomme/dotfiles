# Can't find our fancy prompt engine? Let's use something slightly fancier than nothing!

echo "⚠️  Prezto not found — falling back to basic prompt"
# Allow parameter and command substitutions in your prompt (colors, git info, etc.)
setopt PROMPT_SUBST
# Type a directory name to cd into it (no “cd” prefix needed)
setopt AUTO_CD
# Enable **extended globbing** (e.g. ^, **, ~, etc. in filename patterns)
setopt EXTENDED_GLOB
# Share history across all running shells (live-updates as you type elsewhere)
setopt SHARE_HISTORY
# Don’t record commands that start with a space (for your secret hacks)
setopt HIST_IGNORE_SPACE
# Don’t record duplicate history entries (keeps your history lean)
setopt HIST_IGNORE_DUPS
# When trimming history, expire older duplicates first (preserve your latest tweaks)
setopt HIST_EXPIRE_DUPS_FIRST
# Push the old directory onto the stack when you cd (so “popd” works)
setopt AUTO_PUSHD
# Don’t push the same directory onto the stack twice in a row
setopt PUSHD_IGNORE_DUPS
# Suppress the usual pushd/popd output noise (cleaner terminal)
setopt PUSHD_SILENT

PS1='%n@%m:%~%# '
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
autoload -Uz compinit
compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
_comp_options+=(globdots)
