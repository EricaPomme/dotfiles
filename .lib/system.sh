#!/usr/bin/env bash

# System configuration and cleanup module
# Handles macOS system defaults and system maintenance tasks

#==============================================================================
# macOS System Defaults
#==============================================================================

# Finder configuration
configure_finder() {
    log_debug "configuring Finder"
    
    # Show hidden files and status bar
    defaults write com.apple.finder AppleShowAllFiles -bool true
    defaults write com.apple.finder ShowStatusBar -bool true
    
    # Keep folders on top when sorting by name
    defaults write com.apple.finder _FXSortFoldersFirst -bool true
    defaults write NSGlobalDomain AppleShowAllFiles -bool true
    
    # Set search scope to current folder and disable extension warning
    defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
    defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
}

# Dock and animation configuration
configure_dock() {
    log_debug "configuring Dock"
    
    # Speed up Mission Control animations
    defaults write com.apple.dock expose-animation-duration -float 0.1
}

# Safari configuration
configure_safari() {
    log_debug "configuring Safari"
    
    # Show full URL in address bar (may fail without full disk access)
    defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true 2>/dev/null || \
        log_warning "Safari config failed - may need full disk access"
}

# Restart system UI components to apply changes
restart_ui_components() {
    log_debug "restarting UI components"
    
    killall Finder 2>/dev/null || true
    killall Dock 2>/dev/null || true
}


#==============================================================================
# Linux System Configuration
#==============================================================================

# Apply GNOME desktop settings
apply_gnome_defaults() {
    log_debug "applying GNOME defaults"
    
    # TODO: Implement GNOME settings via gsettings/dconf
    # Examples:
    # - Window manager preferences
    # - File manager settings (Nautilus)
    # - Terminal preferences
    # - Keyboard shortcuts
    # - Theme and appearance settings
    
    log_info "GNOME configuration not yet implemented"
}

# Apply KDE Plasma settings
apply_kde_defaults() {
    log_debug "applying KDE defaults"
    
    # TODO: Implement KDE settings via kwriteconfig5/kconfig
    # Examples:
    # - Window manager (KWin) settings
    # - File manager (Dolphin) preferences
    # - Panel and desktop configuration
    # - Theme and widget settings
    
    log_info "KDE configuration not yet implemented"
}

# Apply generic Linux desktop settings
apply_linux_defaults() {
    log_debug "applying Linux system defaults"
    
    if should_skip "LINUX_DEFAULTS"; then
        return 0
    fi
    
    if ! is_linux; then
        return 0
    fi
    
    log_info "Applying Linux system defaults..."
    
    # Detect desktop environment and apply appropriate settings
    if [[ -n "${GNOME_DESKTOP_SESSION_ID:-}" || "${XDG_CURRENT_DESKTOP}" == *"GNOME"* ]]; then
        apply_gnome_defaults
    elif [[ "${XDG_CURRENT_DESKTOP}" == *"KDE"* ]]; then
        apply_kde_defaults
    else
        log_info "Unknown or unsupported desktop environment: ${XDG_CURRENT_DESKTOP:-none}"
        # TODO: Add support for other DEs:
        # - XFCE (xfconf-query)
        # - i3/sway (config file updates)
        # - MATE (gsettings with mate schemas)
        # - Cinnamon (gsettings with cinnamon schemas)
    fi
    
    log_success "Linux defaults applied"
}

#==============================================================================
# BSD System Configuration
#==============================================================================

# Apply FreeBSD system settings
apply_freebsd_defaults() {
    log_debug "applying FreeBSD defaults"
    
    # TODO: Implement FreeBSD-specific settings
    # Examples:
    # - rc.conf modifications
    # - sysctl settings
    # - Desktop environment configuration
    
    log_info "FreeBSD configuration not yet implemented"
}

# Apply generic BSD settings
apply_bsd_defaults() {
    log_debug "applying BSD system defaults"
    
    if should_skip "BSD_DEFAULTS"; then
        return 0
    fi
    
    # TODO: Detect BSD variant (FreeBSD, OpenBSD, NetBSD)
    case "$(uname -s)" in
        FreeBSD)
            apply_freebsd_defaults
            ;;
        OpenBSD|NetBSD)
            log_info "$(uname -s) configuration not yet implemented"
            ;;
        *)
            log_info "Unknown BSD variant: $(uname -s)"
            ;;
    esac
    
    log_success "BSD defaults applied"
}

#==============================================================================
# Main System Functions
#==============================================================================

# Apply all macOS system defaults
apply_macos_defaults() {
    log_debug "applying macOS system defaults"
    
    if should_skip "MACOS_DEFAULTS"; then
        return 0
    fi
    
    if ! is_macos; then
        return 0
    fi
    
    log_info "Applying macOS system defaults..."
    
    configure_finder
    configure_dock
    configure_safari
    restart_ui_components
    
    log_success "macOS defaults applied"
}

# Apply system defaults for current platform
apply_system_defaults() {
    log_debug "applying system defaults for $OS"
    
    case "$OS" in
        macos)
            apply_macos_defaults
            ;;
        linux)
            apply_linux_defaults
            ;;
        *)
            # Check if it's a BSD system
            case "$(uname -s)" in
                FreeBSD|OpenBSD|NetBSD|DragonFly)
                    apply_bsd_defaults
                    ;;
                *)
                    log_info "System configuration not implemented for: $OS"
                    ;;
            esac
            ;;
    esac
}


