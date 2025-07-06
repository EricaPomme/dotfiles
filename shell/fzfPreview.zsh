#!/usr/bin/env zsh

# Usage: fzfPreview.zsh <file-or-dir>
set -e

TARGET="$1"

show_metadata() {
    echo "--- Metadata ---"
    stat "$TARGET" 2>/dev/null || ls -ld "$TARGET"
    file "$TARGET"
}

if [ -z "$TARGET" ] || [ ! -e "$TARGET" ]; then
    echo "Path does not exist."
    exit 1
fi

if [ -d "$TARGET" ]; then
    echo "📁 Directory: $TARGET"
    ls -lah --color=always "$TARGET" | head -100
    exit 0
fi

# Image preview
is_image() {
    case "${TARGET:l}" in
        *.jpg|*.jpeg|*.png|*.gif|*.bmp|*.webp) return 0;;
        *) return 1;;
    esac
}

if is_image; then
    show_metadata
    exit 0
fi

# Text preview
if file --mime "$TARGET" | grep -q 'text/'; then
    if command -v bat &>/dev/null; then
        bat --style=plain --color=always --line-range=:100 "$TARGET"
    else
        head -100 "$TARGET"
    fi
    exit 0
fi

# Binary: show metadata and hex dump
show_metadata
echo "--- Hex (first 256 bytes) ---"
if command -v xxd &>/dev/null; then
    xxd -l 256 "$TARGET"
else
    od -Ax -tx1 -N 256 "$TARGET"
fi
