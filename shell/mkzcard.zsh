# --- mkzcard.zsh -------------------------------------------------------------
# Source-able zsh library that creates a "zcard" note file in an Obsidian vault.
# Public API: mkzcard [options] [TITLE...]
#
# Defaults (overridable via env):
#   MKZCARD_VAULT_ROOT  -> ~/Dropbox/Obsidian/Work
#   MKZCARD_LINK_ROOT   -> Z
#   MKZCARD_FRONTMATTER -> 1 (set to 0 to default off)
#
# Behavior:
#   - If TITLE (args) is provided: title = args; body = all of STDIN (if any).
#   - Else if STDIN present: title = first non-empty line; body = the rest.
#   - Else: title = "untitled"; body = empty.
#   - Creates: $VAULT_ROOT/$LINK_ROOT/YYYY-MM/<safe>.md  (collision-safe)
#   - Frontmatter (type: zcard, tags: [zcard]) on by default; -n disables.

# ---------- Public ------------------------------------------------------------

mkzcard() {
  emulate -L zsh                            # localize options/behaviour to this fn
  setopt localoptions pipefail              # don’t leak opts to the interactive shell

  # Defaults (pull from env with sensible fallbacks)
  local VAULT_ROOT="${MKZCARD_VAULT_ROOT:-$HOME/Dropbox/Obsidian/Work}"
  local LINK_ROOT="${MKZCARD_LINK_ROOT:-Z}"
  local EMIT_FRONTMATTER="${MKZCARD_FRONTMATTER:-1}"  # 1=yes, 0=no

  # --- tiny argparse ---
  local -a args; args=("$@")
  local i=1 title="" body="" stdin_data=""
  while (( i <= ${#args} )); do
    case "${args[i]}" in
      -h|--help) _mkzcard_usage; return 0 ;;
      -r|--vault-root)
        (( i++ )) || true
        [[ -n "${args[i]:-}" ]] || { print -ru2 "mkzcard: missing value for --vault-root"; return 2; }
        VAULT_ROOT="${args[i]}"
        ;;
      -l|--link-root)
        (( i++ )) || true
        [[ -n "${args[i]:-}" ]] || { print -ru2 "mkzcard: missing value for --link-root"; return 2; }
        LINK_ROOT="${args[i]}"
        ;;
      -n|--no-frontmatter)
        EMIT_FRONTMATTER=0
        ;;
      --) (( i++ )); break ;;
      -*)
        print -ru2 "mkzcard: unknown option: ${args[i]}"
        _mkzcard_usage; return 2 ;;
      *)
        break ;;
    esac
    (( i++ ))
  done

  # Remaining args become the title (joined with spaces)
  if (( i <= ${#args} )); then
    title="${(j: :)args[i,-1]}"
  fi

  # Slurp STDIN if present (preserve all newlines; don’t spawn cat in a tight loop)
  if [[ ! -t 0 ]]; then
    stdin_data="$(< /dev/stdin)"
  fi

  # Decide title/body
  if [[ -n ${title// /} ]]; then
    body="$stdin_data"
  elif [[ -n $stdin_data ]]; then
    # First non-empty line becomes title; remainder becomes body
    local found=0 line rest=""
    while IFS= read -r line || [[ -n $line ]]; do
      if (( ! found )) && [[ -n ${line//[[:space:]]/} ]]; then
        title="$line"; found=1; continue
      fi
      (( found )) && rest+="${line}\n"
    done <<< "$stdin_data"
    body="$rest"
  fi

  [[ -n ${title// /} ]] || title="untitled"

  # Paths
  local month; month="$(_mkzcard_month)"
  local clean_link_root="${LINK_ROOT#/}"; clean_link_root="${clean_link_root%/}"
  local target_dir="${VAULT_ROOT%/}/${clean_link_root:+$clean_link_root/}$month"
  command mkdir -p -- "$target_dir"

  # Filename
  local safe fn path n=1
  safe="$(_mkzcard_sanitize_filename "$title")"
  [[ -n $safe ]] || safe="untitled"
  fn="${safe}.md"
  path="${target_dir}/${fn}"
  while [[ -e $path ]]; do
    (( n++ ))
    path="${target_dir}/${safe} (${n}).md"
  done

  # Content
  local content=""
  if (( EMIT_FRONTMATTER )); then
    local created; created="$(_mkzcard_created)"
    local ytitle;  ytitle="$(_mkzcard_yaml_escape "$title")"
    content+="---"$'\n'
    content+="title: ${ytitle}"$'\n'
    content+="created: ${created}"$'\n'
    content+="type: zcard"$'\n'
    content+="tags: [zcard]"$'\n'
    content+="---"$'\n'
    content+="# ${title}"$'\n'
  else
    content+="# ${title}"$'\n'
  fi

  if [[ -n $body ]]; then
    content+=$'\n'"$body"
    [[ $content == *$'\n' ]] || content+=$'\n'
  else
    content+=$'\n'
  fi

  # Write UTF-8 (no BOM)
  LC_CTYPE=UTF-8 print -nr -- "$content" >| "$path"

  # Output the created path for callers
  print -r -- "$path"
}

# ---------- Private helpers ---------------------------------------------------

_mkzcard_usage() {
  cat <<'EOF'
Usage: mkzcard [-r VAULT_ROOT] [-l LINK_ROOT] [-n] [-h] [TITLE...]
  -r, --vault-root PATH   Override vault root (default: ~/Dropbox/Obsidian/Work)
  -l, --link-root  NAME   Override link root folder (default: Z)
  -n, --no-frontmatter    Do not emit YAML frontmatter (only H1 title)
  -h, --help              Show this help

Behavior:
  - If TITLE (args) is provided: title = args; body = all of STDIN (if any).
  - Else if STDIN present: title = first non-empty line; body = the rest.
  - Else: title = "untitled"; body = empty.

Environment overrides:
  MKZCARD_VAULT_ROOT, MKZCARD_LINK_ROOT, MKZCARD_FRONTMATTER (1 or 0)
EOF
}

# Current month as YYYY-MM (GNU/BSD compatible)
_mkzcard_month()   { command date +%Y-%m }

# Created timestamp YYYY-MM-DD HH:MM
_mkzcard_created() { command date '+%Y-%m-%d %H:%M' }

# Cross-platform filename sanitizer (keeps Windows/macOS/Linux happy)
_mkzcard_sanitize_filename() {
  # awk used for clarity & portability
  command awk '
  BEGIN { ORS="" }
  {
    s=$0
    gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", s)
    gsub(/[\x00-\x1F\x7F]/, "", s)
    gsub(/[][\\/:^|#<>"?*:]/, "-", s)
    gsub(/[[:space:]]+/, " ", s)
    gsub(/[[:space:]]*-[[:space:]]*/, "-", s)
    gsub(/-+/, "-", s)
    sub(/^\.+/, "", s)
    sub(/[. ]+$/, "", s)
    tl=tolower(s)
    if (tl ~ /^(con|prn|aux|nul|com[1-9]|lpt[1-9])$/) s = s "-file"
    if (length(s) > 120) s = substr(s, 1, 120)
    print s
  }' <<< "$1"
}

# Minimal YAML double-quote escaping: \ -> \\ , " -> \"
_mkzcard_yaml_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  print -r -- "\"$s\""
}
# --- end mkzcard.zsh ----------------------------------------------------------
