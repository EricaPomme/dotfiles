mktmpdir() {
    local tmpdir_name=$(uuidgen | tr -d '-')
    
    # Try to create in /tmp first, fallback to home directory, die if both fail
    local tmpdir="/tmp/$tmpdir_name"
    if ! mkdir -p "$tmpdir" 2>/dev/null; then
        tmpdir="$HOME/.tmp/$tmpdir_name"
        if ! mkdir -p "$tmpdir" 2>/dev/null; then
            echo "Error: Could not create temporary directory in /tmp or $HOME/.tmp" >&2
            return 1
        fi
    fi
    
    cd "$tmpdir" || return 1
}