#!/usr/bin/env bash

# Git repository management module
# Handles installation and updates of external git repositories

#==============================================================================
# Repository Configuration
#==============================================================================

# Repository definitions with their metadata
# Format: "name|URL|PATH|CLONE_FLAGS"
# - name: Human-readable identifier for the repository
# - URL: Git repository URL (https or ssh)
# - PATH: Absolute path where repository should be cloned
# - CLONE_FLAGS: Additional flags for git clone (optional, can be empty)
#
# Examples:
# - Basic clone: "repo|https://github.com/user/repo.git|/path/to/repo|"
# - With --recursive: "repo|https://github.com/user/repo.git|/path/to/repo|--recursive"
# - With --depth: "repo|https://github.com/user/repo.git|/path/to/repo|--depth=1"
REPOSITORIES=(
    "prezto|https://github.com/sorin-ionescu/prezto.git|\$HOME/.zprezto|--recursive"
    "oh-my-tmux|https://github.com/gpakosz/.tmux.git|\$HOME/.tmux|"
)

# Get repository information
get_repo_info() {
    local repo_name="$1"
    local repo_info=""
    
    # Find the repository in the array
    for entry in "${REPOSITORIES[@]}"; do
        local entry_name
        entry_name="$(echo "$entry" | cut -d'|' -f1)"
        if [[ "$entry_name" == "$repo_name" ]]; then
            repo_info="$entry"
            break
        fi
    done
    
    if [[ -z "$repo_info" ]]; then
        log_error "Unknown repository: $repo_name"
        return 1
    fi
    
    # Split the repository info: NAME|URL|PATH|CLONE_FLAGS
    IFS="|" read -r name url path flags <<< "$repo_info"
    
    # Expand variables in path
    path="$(eval echo "$path")"
    
    echo "$url" "$path" "$flags"
}

#==============================================================================
# Git Repository Operations
#==============================================================================

# Clone a git repository with error handling
clone_repository() {
    local repo_name="$1"
    local url path flags
    
    log_debug "cloning repository: $repo_name"
    
    # Get repository information
    read -r url path flags <<< "$(get_repo_info "$repo_name")"
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    # Check if already cloned
    if [[ -d "$path" ]]; then
        if [[ -d "$path/.git" ]]; then
            log_info "$repo_name already exists, updating..."
            # Update existing repository
            if git -C "$path" pull --ff-only; then
                log_success "Successfully updated $repo_name"
            else
                log_warning "Failed to update $repo_name (may have local changes)"
                # Continue anyway - repo exists even if update failed
            fi
            return 0
        else
            log_warning "Directory $path exists but is not a git repository"
            log_warning "Please remove it or choose a different path"
            return 1
        fi
    fi
    
    log_info "Cloning $repo_name..."
    
    # Build clone command
    local clone_cmd="git clone"
    if [[ -n "$flags" ]]; then
        clone_cmd="$clone_cmd $flags"
    fi
    clone_cmd="$clone_cmd $url $path"
    
    # Execute clone
    if eval "$clone_cmd"; then
        log_success "Successfully cloned $repo_name"
    else
        log_error "Failed to clone $repo_name"
        return 1
    fi
    
    return 0
}

# Update a git repository
update_repository() {
    local repo_name="$1"
    local url path flags
    
    log_debug "updating repository: $repo_name"
    
    # Get repository information
    read -r url path flags <<< "$(get_repo_info "$repo_name")"
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    # Check if repository exists
    if [[ ! -d "$path" ]]; then
        log_warning "$repo_name not found at $path, skipping update"
        return 0
    fi
    
    # Check if it's actually a git repository
    if [[ ! -d "$path/.git" ]]; then
        log_warning "$path exists but is not a git repository, skipping update"
        return 0
    fi
    
    log_info "Updating $repo_name..."
    
    # Update the repository
    if git -C "$path" pull --ff-only; then
        log_success "Successfully updated $repo_name"
    else
        log_warning "Failed to update $repo_name (may have local changes)"
        return 1
    fi
    
    return 0
}

# Check repository status
check_repository_status() {
    local repo_name="$1"
    local url path flags
    
    log_debug "checking repository status: $repo_name"
    
    # Get repository information
    read -r url path flags <<< "$(get_repo_info "$repo_name")"
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    if [[ ! -d "$path" ]]; then
        echo "missing"
        return 0
    elif [[ ! -d "$path/.git" ]]; then
        echo "not-git"
        return 0
    else
        # Check if there are uncommitted changes
        if git -C "$path" diff --quiet && git -C "$path" diff --cached --quiet; then
            # Check if we're behind origin
            if git -C "$path" fetch --dry-run &>/dev/null; then
                local behind_count
                behind_count=$(git -C "$path" rev-list --count HEAD..origin/$(git -C "$path" branch --show-current) 2>/dev/null || echo "0")
                if [[ "$behind_count" -gt 0 ]]; then
                    echo "behind"
                else
                    echo "up-to-date"
                fi
            else
                echo "up-to-date"
            fi
        else
            echo "dirty"
        fi
    fi
}

#==============================================================================
# Prezto-Specific Operations
#==============================================================================

# Set up Prezto runcoms (configuration files)
setup_prezto_runcoms() {
    log_debug "setting up Prezto runcoms"
    
    local prezto_path="$HOME/.zprezto"
    
    # Check if Prezto is installed
    if [[ ! -d "$prezto_path" ]]; then
        log_warning "Prezto not found at $prezto_path, skipping runcom setup"
        return 1
    fi
    
    log_info "Linking Prezto runcoms..."
    
    local failed_links=0
    local total_links=0
    
    # Link each runcom file
    for rcfile in "$prezto_path"/runcoms/*; do
        # Skip if not a regular file or is README
        [[ ! -f "$rcfile" ]] && continue
        [[ "$(basename "$rcfile")" == "README.md" ]] && continue
        
        local target="$HOME/.$(basename "$rcfile")"
        total_links=$((total_links + 1))
        
        # Skip if target already exists and is not a symlink
        if [[ -e "$target" && ! -L "$target" ]]; then
            log_debug "Prezto runcom '$target' already exists as regular file, skipping"
            continue
        fi
        
        # Skip if symlink already points to the right place
        if [[ -L "$target" && "$(readlink "$target")" == "$rcfile" ]]; then
            log_debug "Prezto runcom '$target' already correctly linked"
            continue
        fi
        
        # Create the symlink
        if ln -sf "$rcfile" "$target"; then
            log_debug "Linked Prezto runcom: $target -> $rcfile"
        else
            log_warning "Failed to link Prezto runcom: $target"
            failed_links=$((failed_links + 1))
        fi
    done
    
    if [[ $failed_links -gt 0 ]]; then
        log_warning "Failed to link $failed_links/$total_links Prezto runcoms"
        return 1
    else
        log_success "Prezto runcoms linked successfully"
        return 0
    fi
}

#==============================================================================
# oh-my-tmux-Specific Operations
#==============================================================================

# Set up oh-my-tmux configuration
setup_oh_my_tmux() {
    log_debug "setting up oh-my-tmux"
    
    local tmux_repo_path="$HOME/.tmux"
    local tmux_config="$HOME/.tmux.conf"
    local tmux_local_config="$HOME/.tmux.conf.local"
    
    # Check if oh-my-tmux is installed
    if [[ ! -d "$tmux_repo_path" ]]; then
        log_warning "oh-my-tmux not found at $tmux_repo_path, skipping setup"
        return 1
    fi
    
    # Link main tmux configuration
    local tmux_source="$tmux_repo_path/.tmux.conf"
    if [[ -f "$tmux_source" ]]; then
        if ln -sf "$tmux_source" "$tmux_config"; then
            log_info "Linked oh-my-tmux config: $tmux_config -> $tmux_source"
        else
            log_error "Failed to link oh-my-tmux configuration"
            return 1
        fi
    else
        log_error "oh-my-tmux configuration not found at $tmux_source"
        return 1
    fi
    
    # Note about local config (handled by dotfiles.sh)
    if [[ ! -e "$tmux_local_config" ]]; then
        log_info "tmux local config will be handled by dotfiles setup"
    fi
    
    log_success "oh-my-tmux setup completed"
    return 0
}

#==============================================================================
# Main Repository Functions
#==============================================================================

# Install all external repositories
install_repositories() {
    log_debug "installing all repositories"
    
    if should_skip "GIT_REPOS"; then
        return 0
    fi
    
    local failed_repos=0
    local total_repos=${#REPOSITORIES[@]}
    
    # Install each repository
    for entry in "${REPOSITORIES[@]}"; do
        local repo_name
        repo_name="$(echo "$entry" | cut -d'|' -f1)"
        if ! clone_repository "$repo_name"; then
            failed_repos=$((failed_repos + 1))
        fi
    done
    
    # Set up repository-specific configurations
    setup_prezto_runcoms || failed_repos=$((failed_repos + 1))
    setup_oh_my_tmux || failed_repos=$((failed_repos + 1))
    
    # Report results
    if [[ $failed_repos -gt 0 ]]; then
        log_warning "Failed to install/configure $failed_repos repositories"
        return 1
    else
        log_success "All repositories installed and configured successfully"
        return 0
    fi
}

# Update all external repositories
update_repositories() {
    log_debug "updating all repositories"
    
    if should_skip "GIT_REPOS"; then
        return 0
    fi
    
    local failed_updates=0
    local total_repos=${#REPOSITORIES[@]}
    
    # Update each repository
    for entry in "${REPOSITORIES[@]}"; do
        local repo_name
        repo_name="$(echo "$entry" | cut -d'|' -f1)"
        if ! update_repository "$repo_name"; then
            failed_updates=$((failed_updates + 1))
        fi
    done
    
    # Report results
    if [[ $failed_updates -gt 0 ]]; then
        log_warning "Failed to update $failed_updates/$total_repos repositories"
        return 1
    else
        log_success "All repositories updated successfully"
        return 0
    fi
}

# Show status of all repositories
status_repositories() {
    log_debug "checking status of all repositories"
    
    local total_repos=${#REPOSITORIES[@]}
    local repos_needing_attention=0
    
    log_info "Repository status:"
    
    for entry in "${REPOSITORIES[@]}"; do
        local repo_name status
        repo_name="$(echo "$entry" | cut -d'|' -f1)"
        status=$(check_repository_status "$repo_name")
        
        case "$status" in
            "up-to-date")
                log_info "  $repo_name: ✓ up to date"
                ;;
            "behind")
                log_warning "  $repo_name: ↓ behind origin"
                repos_needing_attention=$((repos_needing_attention + 1))
                ;;
            "dirty")
                log_warning "  $repo_name: ⚠ has local changes"
                repos_needing_attention=$((repos_needing_attention + 1))
                ;;
            "missing")
                log_error "  $repo_name: ✗ not cloned"
                repos_needing_attention=$((repos_needing_attention + 1))
                ;;
            "not-git")
                log_error "  $repo_name: ✗ exists but not a git repository"
                repos_needing_attention=$((repos_needing_attention + 1))
                ;;
            *)
                log_error "  $repo_name: ? unknown status"
                repos_needing_attention=$((repos_needing_attention + 1))
                ;;
        esac
    done
    
    if [[ $repos_needing_attention -gt 0 ]]; then
        log_warning "$repos_needing_attention/$total_repos repositories need attention"
        return 1
    else
        log_success "All repositories are up to date"
        return 0
    fi
}
