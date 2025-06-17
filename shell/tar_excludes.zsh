# Programmatically generate a tar alias that skips cruft on macOS, Linux, NTFS, etc.

typeset -a TAR_EXCLUDE_PATTERNS=(
  "*/.directory"                  # KDE metadata
  "*/lost+found"                  # ext* recovery dir
  "*/.Trash-*"                    # desktop trash (Linux)
  "*/.gvfs"                       # GNOME virtual fs
  "*/__MACOSX"                    # macOS zip cruft
  "*/._*"                         # macOS resource forks
  "*/.DS_Store"                   # macOS Finder metadata
  "*/.fseventsd"                  # macOS fs events
  "*/.Spotlight-V100"             # macOS index data
  "*~"                            # editor backups
  "#*#"                           # emacs autosaves
  "*.swp"                         # Vim swap files
  "*.bak"                         # generic backups
  "*/$RECYCLE.BIN/*"              # Windows recycle bin folder
  "*/System Volume Information/*" # Windows volume metadata
  "Thumbs.db"                     # Windows thumbnail cache
  "Desktop.ini"                   # Windows desktop settings
  "ehthumbs.db"                   # Windows media thumbnails
  "iconcache_*.db"                # Windows icon cache
)

local EXCLUDE_OPTS=""
for pattern in "${TAR_EXCLUDE_PATTERNS[@]}"; do
  EXCLUDE_OPTS+=" --exclude='${pattern}'"
done

alias tar="tar${EXCLUDE_OPTS}"
