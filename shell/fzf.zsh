#!/usr/bin/env zsh

# Paths
PREVIEW_SCRIPT="${0:A:h}/fzfPreview.zsh"

# Dependency check
for cmd in fzf fd; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Required tool '$cmd' not found in PATH." >&2
        exit 1
    fi
done

# Set includes/excludes
[[ ! "$(pwd)" == "$HOME" ]] && INCLUDES+=("$HOME") || INCLUDES=()
EXCLUDES=(.git .Trash node_modules Library __pycache__)

FD_ARGS=(--type f --type d)
for exclude in $EXCLUDES; do
    FD_ARGS+=("--exclude" "$exclude")
done

for include in $INCLUDES; do
    [ -d "$include" ] && FD_ARGS+=("$include")
done

export PREVIEW_SCRIPT

function f() {
    local selected_file
    selected_file=$(fd . "${FD_ARGS[@]}" | command fzf \
        --height=70% \
        --layout=reverse \
        --style=full \
        --ansi \
        --multi \
        --preview="$PREVIEW_SCRIPT {}" \
        --preview-window=right:50%:wrap) \
        --bind 'ctrl-d=(echo !!!PARENT!!!{})'
    
    
}
