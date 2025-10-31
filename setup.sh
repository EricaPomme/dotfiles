#!/usr/bin/env sh
set -eu

# Simple, portable symlink setup for dotfiles
# - Manifest format: category|source|target
# - Categories: all, mac, linux
# - No external dependencies; pure POSIX sh.

log_info() { printf 'INFO: %s\n' "$*" >&2; }
log_warn() { printf 'WARN: %s\n' "$*" >&2; }
log_error() { printf 'ERROR: %s\n' "$*" >&2; }

usage() {
    cat <<'EOF'
Usage: ./setup.sh [--dry-run] [--yes|-y] [--manifest PATH]
Create symlinks as declared in the manifest (default: symlinks.conf next to this script)

Options:
  --dry-run        Show what would change; make no modifications
  --yes, -y        Auto-backup/replace without prompting
  --manifest PATH  Use a specific manifest path
  -h, --help       Show this help

Manifest format:
  category|source_path|target_path
  Categories: all, mac, linux
  Lines starting with # are comments; blank lines are ignored.
EOF
}

DRY_RUN=0
AUTO_YES=0
MANIFEST="symlinks.conf"

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --yes|-y) AUTO_YES=1; shift ;;
        --manifest) [ $# -ge 2 ] || { log_error "--manifest requires a path"; exit 2; }; MANIFEST=$2; shift 2 ;;
        --manifest=*) MANIFEST=${1#--manifest=}; shift ;;
        -h|--help) usage; exit 0 ;;
        *) log_error "Unknown argument: $1"; usage; exit 2 ;;
    esac
done

UNAME=$(uname -s 2>/dev/null || printf unknown)
case "$UNAME" in
    Darwin) OS="mac" ;;
    Linux)  OS="linux" ;;
    *)      OS=""; log_warn "Unrecognized OS ($UNAME). Only 'all' entries will be processed." ;;
esac

SCRIPT_DIR=$(dirname "$0")
CDPATH= cd -P "$SCRIPT_DIR" 2>/dev/null || { log_error "Cannot cd to script directory: $SCRIPT_DIR"; exit 1; }
DOTFILES_DIR=$(pwd -P)

MANIFEST_PATH="$DOTFILES_DIR/$MANIFEST"
[ -f "$MANIFEST_PATH" ] || { log_error "Manifest not found: $MANIFEST_PATH"; exit 1; }

expand_tilde() {
    case "$1" in
        "~")
            printf '%s' "$HOME"
            ;;
        "~/"*)
            rest=$(printf '%s' "$1" | sed 's|^~/||')
            printf '%s/%s' "$HOME" "$rest"
            ;;
        *)
            printf '%s' "$1"
            ;;
    esac
}

ensure_parent() {
    parent=$1
    [ -d "$parent" ] && return 0
    log_info "Create directory: $parent"
    [ "$DRY_RUN" -eq 0 ] && mkdir -p "$parent"
}

backup_path() {
    ts=$(date +'%Y%m%d_%H%M%S')
    printf '%s.%s.backup' "$1" "$ts"
}

CREATED=0
UPDATED=0
BACKED_UP=0
SKIPPED=0
FAILED=0
TOTAL=0

link_one() {
    src=$1
    tgt=$2
    TOTAL=$((TOTAL + 1))

    if [ ! -e "$src" ] && [ ! -L "$src" ]; then
        log_warn "Source missing, skipping: $src"
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi

    parent=$(dirname "$tgt")
    ensure_parent "$parent" || { log_error "Failed to create parent: $parent"; FAILED=$((FAILED + 1)); return 1; }

    if [ -L "$tgt" ]; then
        cur=$(readlink "$tgt" 2>/dev/null || printf '')
        if [ "$cur" = "$src" ]; then
            log_info "OK: $tgt already links to $src"
            SKIPPED=$((SKIPPED + 1))
            return 0
        fi
        log_info "Replace symlink: $tgt (was -> $cur) now -> $src"
        if [ "$DRY_RUN" -eq 0 ]; then
            rm -f "$tgt" || { log_error "Failed to remove existing symlink: $tgt"; FAILED=$((FAILED + 1)); return 1; }
            ln -s "$src" "$tgt" || { log_error "Failed to link: $tgt -> $src"; FAILED=$((FAILED + 1)); return 1; }
        fi
        UPDATED=$((UPDATED + 1))
        return 0
    fi

    if [ -e "$tgt" ]; then
        bkp=$(backup_path "$tgt")
        ans="n"
        if [ "$AUTO_YES" -eq 1 ]; then
            ans="y"
        elif [ -t 0 ]; then
            printf 'Target exists (not a symlink): %s\n' "$tgt" >&2
            printf 'Move it to backup "%s"? [y/N] ' "$bkp" >&2
            read -r ans || ans="n"
        else
            log_warn "Non-interactive: skipping existing path (use --yes to auto-backup): $tgt"
        fi
        case "$ans" in
            y|Y|yes|YES)
                log_info "Backup: $tgt -> $bkp"
                [ "$DRY_RUN" -eq 0 ] && mv "$tgt" "$bkp"
                BACKED_UP=$((BACKED_UP + 1))
                ;;
            *) SKIPPED=$((SKIPPED + 1)); return 0 ;;
        esac
    fi

    log_info "Link: $tgt -> $src"
    if [ "$DRY_RUN" -eq 0 ]; then
        ln -s "$src" "$tgt" || { log_error "Failed to link: $tgt -> $src"; FAILED=$((FAILED + 1)); return 1; }
    fi
    CREATED=$((CREATED + 1))
}

log_info "Dotfiles dir: $DOTFILES_DIR"
log_info "Manifest: $MANIFEST_PATH"
[ -n "$OS" ] && log_info "OS detected: $OS" || log_info "OS unknown; using 'all' entries only"

# Read manifest: category|source|target
while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac

    # Parse three fields with '|' separators
    catg=${line%%|*}
    rest=${line#*|}
    [ "$rest" = "$line" ] && { log_warn "Malformed line (no separators): $line"; continue; }
    src_rel=${rest%%|*}
    tgt_spec=${rest#*|}

    if [ -z "$catg" ] || [ -z "$src_rel" ] || [ -z "$tgt_spec" ]; then
        log_warn "Malformed line (need 3 fields): $line"
        continue
    fi

    process=0
    [ "$catg" = "all" ] && process=1
    if [ -n "$OS" ] && [ "$catg" = "$OS" ]; then process=1; fi
    [ "$process" -eq 1 ] || continue

    src_abs="$DOTFILES_DIR/$src_rel"
    tgt_path=$(expand_tilde "$tgt_spec")

    link_one "$src_abs" "$tgt_path"
done < "$MANIFEST_PATH"

log_info "Done. total=$TOTAL created=$CREATED updated=$UPDATED backups=$BACKED_UP skipped=$SKIPPED failed=$FAILED"
