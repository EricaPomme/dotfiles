# Initialize completion system
autoload -Uz compinit
compinit

# Set up completion styles
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
_comp_options+=(globdots)

# Set shell options
setopt PROMPT_SUBST

# Git status cache to avoid repeated calls
typeset -A git_status_cache
typeset -A git_upstream_cache

# Get friendly current working directory (with ~ substitution)
get_friendly_cwd() {
    echo "${PWD/#$HOME/~}"
}

# Get virtual environment info
get_venv_info() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        local venv_name="${VIRTUAL_ENV:t}"
        echo " (venv:$venv_name)"
    fi
}

# Get cached upstream status (checks every 5 minutes)
get_git_upstream_status() {
    local repo_path="$1"
    local branch="$2"
    local cache_key="${repo_path}|${branch}"
    local now=$(date +%s)
    
    # Check if we have cached data and it's still fresh (5 minutes = 300 seconds)
    if [[ -n "${git_upstream_cache[$cache_key]}" ]]; then
        local cached_data="${git_upstream_cache[$cache_key]}"
        local timestamp="${cached_data%%|*}"
        local status="${cached_data#*|}"
        
        if (( now - timestamp < 300 )); then
            echo "$status"
            return
        fi
    fi
    
    # Get upstream comparison with timeout
    local upstream ahead behind status_result
    
    # Quick timeout check - if git fetch takes too long, skip
    if timeout 3 git fetch --dry-run &>/dev/null; then
        upstream=$(git rev-parse --abbrev-ref "$branch@{upstream}" 2>/dev/null)
        if [[ $? -eq 0 && -n "$upstream" ]]; then
            ahead=$(git rev-list "$upstream..HEAD" --count 2>/dev/null || echo "0")
            behind=$(git rev-list "HEAD..$upstream" --count 2>/dev/null || echo "0")
            status_result="true|$ahead|$behind"
        else
            status_result="false|0|0"
        fi
    else
        status_result="false|0|0"
    fi
    
    # Cache the result
    git_upstream_cache[$cache_key]="$now|$status_result"
    echo "$status_result"
}

# Enhanced Git status function with caching
get_git_status() {
    # Quick check if we're in a git repo
    local git_dir
    git_dir=$(git rev-parse --git-dir 2>/dev/null) || return
    
    local repo_path
    repo_path=$(git rev-parse --show-toplevel 2>/dev/null) || return
    
    local cache_key="$repo_path"
    local now=$(date +%s)
    
    # Check cache (refresh every 30 seconds for local status)
    if [[ -n "${git_status_cache[$cache_key]}" ]]; then
        local cached_data="${git_status_cache[$cache_key]}"
        local timestamp="${cached_data%%|*}"
        local status="${cached_data#*|}"
        
        if (( now - timestamp < 30 )); then
            echo "$status"
            return
        fi
    fi
    
    # Get branch info
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        # Probably in detached HEAD state
        branch=$(git rev-parse --short HEAD 2>/dev/null)
        branch="${branch:+(${branch})}"
        branch="${branch:-(unknown)}"
    fi
    
    # Get working directory status
    local git_status staged=0 modified=0 untracked=0 conflicts=0
    git_status=$(git --no-optional-locks status --porcelain=v1 2>/dev/null)
    
    if [[ -n "$git_status" ]]; then
        while IFS= read -r line; do
            local x="${line:0:1}"
            local y="${line:1:1}"
            
            # Check for conflicts
            if [[ "$x" == "U" || "$y" == "U" || ("$x" == "A" && "$y" == "A") || ("$x" == "D" && "$y" == "D") ]]; then
                ((conflicts++))
            elif [[ "$x" == "?" && "$y" == "?" ]]; then
                ((untracked++))
            else
                [[ "$x" != " " && "$x" != "?" ]] && ((staged++))
                [[ "$y" != " " && "$y" != "?" ]] && ((modified++))
            fi
        done <<< "$git_status"
    fi
    
    # Check for stash
    local has_stash=false
    if [[ $(git stash list 2>/dev/null | wc -l) -gt 0 ]]; then
        has_stash=true
    fi
    
    # Get upstream status (cached for 5 minutes)
    local upstream_info
    upstream_info=$(get_git_upstream_status "$repo_path" "$branch")
    local has_upstream="${upstream_info%%|*}"
    local ahead="${upstream_info#*|}"
    ahead="${ahead%%|*}"
    local behind="${upstream_info##*|}"
    
    # Build status string
    local status_parts=()
    
    # Add change indicators
    [[ $conflicts -gt 0 ]] && status_parts+=("!$conflicts")
    [[ $staged -gt 0 ]] && status_parts+=("+$staged")
    [[ $modified -gt 0 ]] && status_parts+=("~$modified")
    [[ $untracked -gt 0 ]] && status_parts+=("?$untracked")
    [[ "$has_stash" == "true" ]] && status_parts+=('$')
    
    # Add upstream indicators
    if [[ "$has_upstream" == "true" ]]; then
        [[ $behind -gt 0 ]] && status_parts+=("↓$behind")
        [[ $ahead -gt 0 ]] && status_parts+=("↑$ahead")
    fi
    
    local status_suffix=""
    if [[ ${#status_parts[@]} -gt 0 ]]; then
        status_suffix=" [${(j: :)status_parts}]"
    fi
    
    local full_status="$branch$status_suffix"
    
    # Cache the result
    git_status_cache[$cache_key]="$now|$full_status"
    echo "$full_status"
}

# Update terminal title
update_title() {
    local title_path=$(get_friendly_cwd)
    # Set terminal title (works in most terminals)
    print -Pn "\e]0;$title_path - %n@%m\a"
}

# Detect Darwin first (no /etc/os-release on macOS), else pull ID from os-release
if [ "$(uname -s)" = "Darwin" ]; then
    distro="darwin"
elif [ -r /etc/os-release ]; then
    distro=$(awk -F= '/^ID=/{gsub(/"/,""); print $2}' /etc/os-release)
else
    distro=""
fi

# Map distro → Nerd Font glyph (blank if unknown)
case "$distro" in
    ubuntu)         icon='\uf31c' ;;
    debian)         icon='\uf306' ;;
    fedora)         icon='\uf30a' ;;
    arch|archlinux) icon='\uf303' ;;
    manjaro)        icon='\uf312' ;;
    centos)         icon='\uf304' ;;
    opensuse*|suse*)icon='\uf314' ;;
    darwin)         icon='\ue720' ;;
    *)              icon=''       ;;
esac

# Wrap it up
[[ -n "$icon" ]] && os_tag=$(echo -e " $icon ") || os_tag=" "

# Custom prompt function
build_prompt() {
    # Capture exit status
    local exit_code=$?
    
    # Update title
    update_title
    
    # Display user, host, and current directory
    local user_info
    if [[ $EUID -eq 0 ]]; then
        # Root user - red background
        user_info="%K{red}%F{white}$os_tag%n %k%f"
    else
        # Normal user - blue background
        user_info="%K{blue}%F{white}$os_tag%n %k%f"
    fi
    
    local host_info="%K{white}%F{blue} %m %k%f"
    local location_info="$(get_friendly_cwd)"
    
    # Get Git status if in a Git repository
    local git_info
    git_info=$(get_git_status)
    local git_status_display
    if [[ -n "$git_info" ]]; then
        git_status_display="%F{cyan} $git_info %f"
    else
        git_status_display=" "
    fi
    
    # Build first line
    local first_line="$user_info$host_info$git_status_display$location_info"
    
    # Build second line with exit status
    local status_info
    if [[ $exit_code -eq 0 ]]; then
        status_info="%K{black}%F{green} 0 %k%f"
    else
        status_info="%K{black}%F{red} $exit_code %k%f"
    fi
    
    local second_line="$status_info> "
    
    # Return the complete prompt
    echo "$first_line"$'\n'"$second_line"
}

PROMPT='$(build_prompt)'
