#!/usr/bin/env sh
set -eu

# Simple, portable symlink setup for dotfiles
# - Manifest format: category|mode|noclobber|chmod|user|group|source|target
# - Categories: all, mac, linux, bsd
# - No external dependencies; pure POSIX sh.

log_info() { printf 'INFO: %s\n' "$*" >&2; }
log_warn() { printf 'WARN: %s\n' "$*" >&2; }
log_error() { printf 'ERROR: %s\n' "$*" >&2; }

usage() {
    cat <<'EOF'
Usage: ./setup.sh [--dry-run] [--manifest PATH]
Create symlinks as declared in the manifest (default: dotfiles.conf next to this script)

Options:
  --dry-run        Show what would change; make no modifications
  --manifest PATH  Use a specific manifest path
  -h, --help       Show this help
EOF
}

DRY_RUN=0
MANIFEST="dotfiles.conf"

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
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
    *BSD)   OS="bsd" ;;
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

validate_chmod_spec() {
    spec=$1
    [ "$spec" = "-" ] && return 0

    # Accept octal 3-4 digits
    printf '%s' "$spec" | grep -Eq '^[0-7]{3,4}$' && return 0

    # Accept symbolic modes like u=rwX,go=rX
    printf '%s' "$spec" | grep -Eq '^[ugoa]*([+-=][rwxXstugo]*)+(,[ugoa]*([+-=][rwxXstugo]*)+)*$' && return 0

    return 1
}

user_exists() {
    u=$1
    [ "$u" = "-" ] && return 0
    id -u "$u" >/dev/null 2>&1
}

group_exists() {
    g=$1
    [ "$g" = "-" ] && return 0
    if command -v getent >/dev/null 2>&1; then
        getent group "$g" >/dev/null 2>&1
    else
        dscl . -read "/Groups/$g" >/dev/null 2>&1
    fi
}

apply_chown() {
    user_spec=$1
    group_spec=$2
    tgt=$3

    [ "$user_spec" = "-" ] && [ "$group_spec" = "-" ] && return 0

    spec=""
    if [ "$user_spec" != "-" ]; then
        spec=$user_spec
    fi
    spec="$spec:"
    if [ "$group_spec" != "-" ]; then
        spec="${spec%:}:$group_spec"
    fi

    if [ "$DRY_RUN" -eq 0 ]; then
        if chown "$spec" "$tgt" 2>/dev/null; then
            return 0
        fi
        # fallback with sudo if available/needed
        if command -v sudo >/dev/null 2>&1; then
            sudo chown "$spec" "$tgt" 2>/dev/null && return 0
        fi
        log_error "Failed to chown $tgt to $spec"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

CREATED=0
UPDATED=0
BACKED_UP=0
SKIPPED=0
FAILED=0
TOTAL=0

do_link() {
    src=$1
    tgt=$2
    noclobber=$3
    chmod_spec=$4
    user_spec=$5
    group_spec=$6
    TOTAL=$((TOTAL + 1))

    if [ ! -e "$src" ] && [ ! -L "$src" ]; then
        log_warn "Source missing, skipping: $src"
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi

    if ! validate_chmod_spec "$chmod_spec"; then
        log_error "Invalid chmod spec '$chmod_spec' for target: $tgt"
        FAILED=$((FAILED + 1))
        return 1
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
        if [ "$noclobber" -eq 1 ]; then
            log_warn "Noclobber set and symlink exists, skipping: $tgt"
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
        if [ "$noclobber" -eq 1 ]; then
            log_warn "Noclobber set and target exists, skipping: $tgt"
            SKIPPED=$((SKIPPED + 1))
            return 0
        fi
        bkp=$(backup_path "$tgt")
        log_info "Backup: $tgt -> $bkp"
        [ "$DRY_RUN" -eq 0 ] && mv "$tgt" "$bkp"
        BACKED_UP=$((BACKED_UP + 1))
    fi

    log_info "Link: $tgt -> $src"
    if [ "$DRY_RUN" -eq 0 ]; then
        ln -s "$src" "$tgt" || { log_error "Failed to link: $tgt -> $src"; FAILED=$((FAILED + 1)); return 1; }
        if [ "$chmod_spec" != "-" ] && [ -n "$chmod_spec" ]; then
            chmod "$chmod_spec" "$tgt" || { log_error "Failed to chmod: $tgt"; FAILED=$((FAILED + 1)); return 1; }
        fi
        apply_chown "$user_spec" "$group_spec" "$tgt" || return 1
    fi
    CREATED=$((CREATED + 1))
}

do_copy() {
    src=$1
    tgt=$2
    noclobber=$3
    chmod_spec=$4
    user_spec=$5
    group_spec=$6
    TOTAL=$((TOTAL + 1))

    if [ ! -e "$src" ] && [ ! -L "$src" ]; then
        log_warn "Source missing, skipping: $src"
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi

    if ! validate_chmod_spec "$chmod_spec"; then
        log_error "Invalid chmod spec '$chmod_spec' for target: $tgt"
        FAILED=$((FAILED + 1))
        return 1
    fi

    parent=$(dirname "$tgt")
    ensure_parent "$parent" || { log_error "Failed to create parent: $parent"; FAILED=$((FAILED + 1)); return 1; }

    if [ -e "$tgt" ] || [ -L "$tgt" ]; then
        if [ "$noclobber" -eq 1 ]; then
            log_warn "Noclobber set and target exists, skipping: $tgt"
            SKIPPED=$((SKIPPED + 1))
            return 0
        fi
        bkp=$(backup_path "$tgt")
        log_info "Backup: $tgt -> $bkp"
        [ "$DRY_RUN" -eq 0 ] && mv "$tgt" "$bkp"
        BACKED_UP=$((BACKED_UP + 1))
    fi

    log_info "Copy: $src -> $tgt"
    if [ "$DRY_RUN" -eq 0 ]; then
        if [ -d "$src" ]; then
            cp -r "$src" "$tgt" || { log_error "Failed to copy: $src -> $tgt"; FAILED=$((FAILED + 1)); return 1; }
        else
            cp "$src" "$tgt" || { log_error "Failed to copy: $src -> $tgt"; FAILED=$((FAILED + 1)); return 1; }
        fi
        if [ "$chmod_spec" != "-" ] && [ -n "$chmod_spec" ]; then
            chmod "$chmod_spec" "$tgt" || { log_error "Failed to chmod: $tgt"; FAILED=$((FAILED + 1)); return 1; }
        fi
        apply_chown "$user_spec" "$group_spec" "$tgt" || return 1
    fi
    CREATED=$((CREATED + 1))
}

do_newfile() {
    src_rel=$1
    tgt=$2
    noclobber=$3
    chmod_spec=$4
    user_spec=$5
    group_spec=$6
    TOTAL=$((TOTAL + 1))

    if [ "$src_rel" != "-" ]; then
        log_warn "newfile mode ignores source; expected '-' but got: $src_rel"
    fi

    if ! validate_chmod_spec "$chmod_spec"; then
        log_error "Invalid chmod spec '$chmod_spec' for target: $tgt"
        FAILED=$((FAILED + 1))
        return 1
    fi

    parent=$(dirname "$tgt")
    ensure_parent "$parent" || { log_error "Failed to create parent: $parent"; FAILED=$((FAILED + 1)); return 1; }

    if [ -e "$tgt" ] || [ -L "$tgt" ]; then
        if [ "$noclobber" -eq 1 ]; then
            log_warn "Noclobber set and target exists, skipping: $tgt"
            SKIPPED=$((SKIPPED + 1))
            return 0
        fi
        bkp=$(backup_path "$tgt")
        log_info "Backup: $tgt -> $bkp"
        [ "$DRY_RUN" -eq 0 ] && mv "$tgt" "$bkp"
        BACKED_UP=$((BACKED_UP + 1))
    fi

    log_info "Create file: $tgt"
    if [ "$DRY_RUN" -eq 0 ]; then
        : > "$tgt" || { log_error "Failed to create file: $tgt"; FAILED=$((FAILED + 1)); return 1; }
        if [ "$chmod_spec" != "-" ] && [ -n "$chmod_spec" ]; then
            chmod "$chmod_spec" "$tgt" || { log_error "Failed to chmod: $tgt"; FAILED=$((FAILED + 1)); return 1; }
        fi
        apply_chown "$user_spec" "$group_spec" "$tgt" || return 1
    fi
    CREATED=$((CREATED + 1))
}

do_newdir() {
    src_rel=$1
    tgt=$2
    noclobber=$3
    chmod_spec=$4
    user_spec=$5
    group_spec=$6
    TOTAL=$((TOTAL + 1))

    if [ "$src_rel" != "-" ]; then
        log_warn "newdir mode ignores source; expected '-' but got: $src_rel"
    fi

    if ! validate_chmod_spec "$chmod_spec"; then
        log_error "Invalid chmod spec '$chmod_spec' for target: $tgt"
        FAILED=$((FAILED + 1))
        return 1
    fi

    parent=$(dirname "$tgt")
    ensure_parent "$parent" || { log_error "Failed to create parent: $parent"; FAILED=$((FAILED + 1)); return 1; }

    if [ -e "$tgt" ] || [ -L "$tgt" ]; then
        if [ "$noclobber" -eq 1 ]; then
            log_warn "Noclobber set and target exists, skipping: $tgt"
            SKIPPED=$((SKIPPED + 1))
            return 0
        fi
        bkp=$(backup_path "$tgt")
        log_info "Backup: $tgt -> $bkp"
        [ "$DRY_RUN" -eq 0 ] && mv "$tgt" "$bkp"
        BACKED_UP=$((BACKED_UP + 1))
    fi

    log_info "Create dir: $tgt"
    if [ "$DRY_RUN" -eq 0 ]; then
        mkdir -p "$tgt" || { log_error "Failed to create dir: $tgt"; FAILED=$((FAILED + 1)); return 1; }
        if [ "$chmod_spec" != "-" ] && [ -n "$chmod_spec" ]; then
            chmod "$chmod_spec" "$tgt" || { log_error "Failed to chmod: $tgt"; FAILED=$((FAILED + 1)); return 1; }
        fi
        apply_chown "$user_spec" "$group_spec" "$tgt" || return 1
    fi
    CREATED=$((CREATED + 1))
}

log_info "Dotfiles dir: $DOTFILES_DIR"
log_info "Manifest: $MANIFEST_PATH"
[ -n "$OS" ] && log_info "OS detected: $OS" || log_info "OS unknown; using 'all' entries only"

# Read manifest: category|mode|noclobber|chmod|user|group|source|target
while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac

    # Parse eight fields with '|' separators
    catg=${line%%|*}
    rest=${line#*|}
    [ "$rest" = "$line" ] && { log_warn "Malformed line (no separators): $line"; continue; }
    mode=${rest%%|*}
    rest=${rest#*|}
    noclobber=${rest%%|*}
    rest=${rest#*|}
    chmod_spec=${rest%%|*}
    rest=${rest#*|}
    user_spec=${rest%%|*}
    rest=${rest#*|}
    group_spec=${rest%%|*}
    rest=${rest#*|}
    src_rel=${rest%%|*}
    tgt_spec=${rest#*|}

    if [ -z "$catg" ] || [ -z "$mode" ] || [ -z "$noclobber" ] || [ -z "$chmod_spec" ] || [ -z "$user_spec" ] || [ -z "$group_spec" ] || [ -z "$src_rel" ] || [ -z "$tgt_spec" ]; then
        log_warn "Malformed line (need 8 fields): $line"
        continue
    fi

    process=0
    [ "$catg" = "all" ] && process=1
    if [ -n "$OS" ] && [ "$catg" = "$OS" ]; then process=1; fi
    [ "$process" -eq 1 ] || continue

    if ! user_exists "$user_spec"; then
        log_error "User not found: $user_spec"
        FAILED=$((FAILED + 1))
        continue
    fi
    if ! group_exists "$group_spec"; then
        log_error "Group not found: $group_spec"
        FAILED=$((FAILED + 1))
        continue
    fi

    src_abs="$DOTFILES_DIR/$src_rel"
    tgt_path=$(expand_tilde "$tgt_spec")

    case "$mode" in
        link) do_link "$src_abs" "$tgt_path" "$noclobber" "$chmod_spec" "$user_spec" "$group_spec" ;;
        copy) do_copy "$src_abs" "$tgt_path" "$noclobber" "$chmod_spec" "$user_spec" "$group_spec" ;;
        newfile) do_newfile "$src_rel" "$tgt_path" "$noclobber" "$chmod_spec" "$user_spec" "$group_spec" ;;
        newdir) do_newdir "$src_rel" "$tgt_path" "$noclobber" "$chmod_spec" "$user_spec" "$group_spec" ;;
        *) log_warn "Unknown mode '$mode', skipping: $line" ;;
    esac
done < "$MANIFEST_PATH"

log_info "Done. total=$TOTAL created=$CREATED updated=$UPDATED backups=$BACKED_UP skipped=$SKIPPED failed=$FAILED"
