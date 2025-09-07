#!/usr/bin/env bash

# Dotfiles symlink management module
# Handles creation and management of dotfile symlinks

#==============================================================================
# Symlink Configuration
#==============================================================================

# Get OS-specific zsh configurations
get_os_zsh_configs() {
    log_debug "determining OS-specific zsh configurations"
    
    if is_macos; then
        echo "shell/zshrc_macos" "shell/zprofile_macos"
    elif is_linux; then
        echo "shell/zshrc_linux" "shell/zprofile_linux"
    else
        log_warning "Unknown OS: $OS, defaulting to Linux zsh configs"
        echo "shell/zshrc_linux" "shell/zprofile_linux"
    fi
}

# Get OS-specific additional symlinks
get_os_specific_symlinks() {
    log_debug "determining OS-specific symlinks"
    
    if is_macos; then
        echo "hammerspoon|$HOME/.hammerspoon"
    fi
    # Linux doesn't have OS-specific symlinks currently
}

# Generate all symlink pairs
generate_symlink_pairs() {
    log_debug "generating symlink pairs"
    
    # Common symlinks for all platforms
    cat << EOF
editorconfig|$HOME/.editorconfig
git/gitconfig|$HOME/.gitconfig
helix|$HOME/.config/helix
shell/p10k.zsh|$HOME/.p10k.zsh
tmux/.tmux.conf.local|$HOME/.tmux.conf.local
EOF
    
    # OS-specific symlinks
    local os_symlinks
    os_symlinks=$(get_os_specific_symlinks)
    if [[ -n "$os_symlinks" ]]; then
        echo "$os_symlinks"
    fi
    
    # OS-specific zsh configurations
    local zshrc_source zprofile_source
    read -r zshrc_source zprofile_source <<< "$(get_os_zsh_configs)"
    
    echo "$zprofile_source|$HOME/.zprofile"
    echo "$zshrc_source|$HOME/.zshrc"
}

#==============================================================================
# Symlink Management
#==============================================================================

# Create a backup of an existing file
backup_existing_file() {
    local target="$1"
    local backup_file
    
    if [[ -e "$target" && ! -L "$target" ]]; then
        backup_file="${target}.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Backing up existing file '$target' to '$backup_file'"
        
        mv "$target" "$backup_file" || {
            log_error "Failed to backup '$target' to '$backup_file'"
            return 1
        }
    fi
}

# Create a single symlink with proper error handling
create_symlink() {
    local source_path="$1"
    local target_path="$2"
    local absolute_source
    
    log_debug "creating symlink: $target_path -> $source_path"
    
    # Convert to absolute path
    absolute_source="$(pwd)/$source_path"
    
    # Validate source exists
    if [[ ! -e "$absolute_source" ]]; then
        log_warning "Source file '$absolute_source' does not exist, skipping symlink"
        return 1
    fi
    
    # Create target directory if needed
    local target_dir
    target_dir="$(dirname "$target_path")"
    if [[ ! -d "$target_dir" ]]; then
        log_debug "creating directory: $target_dir"
        mkdir -p "$target_dir" || {
            log_error "Failed to create directory '$target_dir'"
            return 1
        }
    fi
    
    # Check if symlink already exists and is correct
    if [[ -L "$target_path" ]]; then
        local current_target
        current_target="$(readlink "$target_path")"
        if [[ "$current_target" == "$absolute_source" ]]; then
            log_debug "symlink '$target_path' already correctly points to '$absolute_source'"
            return 0
        else
            log_debug "symlink '$target_path' points to wrong target: '$current_target', updating"
        fi
    fi
    
    # Backup existing file if needed
    backup_existing_file "$target_path" || return 1
    
    # Create the symlink
    if ln -sf "$absolute_source" "$target_path"; then
        log_info "Created symlink: $target_path -> $absolute_source"
    else
        log_error "Failed to create symlink from '$absolute_source' to '$target_path'"
        return 1
    fi
}

# Process all symlinks from the configuration
create_all_symlinks() {
    log_debug "creating all symlinks"
    
    local failed_symlinks=0
    local total_symlinks=0
    
    # Process each symlink pair
    while IFS="|" read -r source_path target_path; do
        # Skip empty lines
        [[ -z "$source_path" || -z "$target_path" ]] && continue
        
        total_symlinks=$((total_symlinks + 1))
        
        if ! create_symlink "$source_path" "$target_path"; then
            failed_symlinks=$((failed_symlinks + 1))
        fi
    done <<< "$(generate_symlink_pairs)"
    
    # Report results
    local successful_symlinks=$((total_symlinks - failed_symlinks))
    log_info "Symlink creation complete: $successful_symlinks/$total_symlinks successful"
    
    if [[ $failed_symlinks -gt 0 ]]; then
        log_warning "$failed_symlinks symlink(s) failed to create"
        return 1
    fi
    
    return 0
}

#==============================================================================
# SSH Configuration
#==============================================================================

# Set up SSH configuration
setup_ssh_config() {
    log_debug "setting up SSH configuration"
    
    local ssh_dir="$HOME/.ssh"
    local ssh_config="$ssh_dir/config"
    local ssh_template="ssh/config_template"
    
    # Create .ssh directory
    if [[ ! -d "$ssh_dir" ]]; then
        log_info "Creating SSH directory: $ssh_dir"
        mkdir -p "$ssh_dir" || {
            log_error "Failed to create SSH directory '$ssh_dir'"
            return 1
        }
    fi
    
    # Only create config if it doesn't exist
    if [[ ! -f "$ssh_config" ]]; then
        if [[ -f "$ssh_template" ]]; then
            log_info "Creating SSH config from template"
            cp "$ssh_template" "$ssh_config" && chmod 600 "$ssh_config" || {
                log_error "Failed to create SSH config from template"
                return 1
            }
            log_success "SSH config created successfully"
        else
            log_warning "SSH config template not found at '$ssh_template'"
            return 1
        fi
    else
        log_info "SSH config already exists at '$ssh_config', not overwriting"
    fi
}

#==============================================================================
# Shell Configuration
#==============================================================================

# Set up zsh as default shell
setup_default_shell() {
    log_debug "setting up default shell"
    
    if should_skip "VERIFY_ESSENTIALS"; then
        log_info "Skipping default shell setup (BYPASS_VERIFY_ESSENTIALS=true)"
        return 0
    fi
    
    require_command zsh
    
    local zsh_path
    zsh_path="$(command -v zsh)"
    
    # Check if zsh is already the default shell
    if [[ "$SHELL" == "$zsh_path" ]]; then
        log_info "zsh is already the default shell"
        return 0
    fi
    
    # Add zsh to /etc/shells if not present
    if ! grep -q "^$zsh_path$" /etc/shells 2>/dev/null; then
        log_info "Adding zsh to /etc/shells"
        echo "$zsh_path" | sudo tee -a /etc/shells || {
            log_warning "Failed to add zsh to /etc/shells"
            return 1
        }
    fi
    
    # Change default shell
    log_info "Changing default shell to zsh for user '$USER'"
    chsh -s "$zsh_path" || {
        log_warning "Failed to change default shell to zsh"
        return 1
    }
    log_success "Default shell changed to zsh"
}

#==============================================================================
# Main Dotfiles Functions
#==============================================================================

# Set up all dotfiles configurations
setup_dotfiles() {
    log_debug "setting up dotfiles"
    
    if should_skip "SETUP_DOTFILES"; then
        return 0
    fi
    
    # Validate required environment variables
    if [[ -z "${HOME:-}" ]]; then
        log_critical "HOME environment variable is not defined"
    fi
    
    local setup_failed=false
    
    # Create symlinks
    if ! create_all_symlinks; then
        setup_failed=true
    fi
    
    # Set up SSH configuration
    if ! setup_ssh_config; then
        setup_failed=true
    fi
    
    # Set up default shell
    if ! setup_default_shell; then
        setup_failed=true
    fi
    
    if [[ "$setup_failed" == "true" ]]; then
        log_error "Some dotfile setup operations failed"
        return 1
    else
        log_success "Dotfiles setup completed successfully"
        return 0
    fi
}

# Validate dotfiles setup
validate_dotfiles() {
    log_debug "validating dotfiles setup"
    
    local validation_failed=false
    local broken_symlinks=0
    local total_symlinks=0
    
    # Check all expected symlinks
    while IFS="|" read -r source_path target_path; do
        # Skip empty lines
        [[ -z "$source_path" || -z "$target_path" ]] && continue
        
        total_symlinks=$((total_symlinks + 1))
        
        if [[ -L "$target_path" ]]; then
            local link_target
            link_target="$(readlink "$target_path")"
            if [[ ! -e "$link_target" ]]; then
                log_warning "Broken symlink detected: $target_path -> $link_target"
                broken_symlinks=$((broken_symlinks + 1))
                validation_failed=true
            fi
        elif [[ ! -e "$target_path" ]]; then
            log_warning "Missing symlink: $target_path"
            validation_failed=true
        fi
    done <<< "$(generate_symlink_pairs)"
    
    if [[ "$validation_failed" == "true" ]]; then
        log_error "Dotfiles validation failed: $broken_symlinks broken symlinks detected"
        return 1
    else
        log_success "All dotfiles validated successfully ($total_symlinks symlinks)"
        return 0
    fi
}
