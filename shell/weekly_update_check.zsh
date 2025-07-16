# ~/dotfiles/shell/weekly_update_check.zsh
# -----------------------------------------------------------------------------
# Weekly update reminder - prompts to run update script if it's been a week
# -----------------------------------------------------------------------------

_check_weekly_update() {
    local timestamp_file="${HOME}/.last_update_check"
    local current_time=$(date +%s)
    local week_seconds=604800  # 7 days * 24 hours * 60 minutes * 60 seconds
    
    if [[ -f "$timestamp_file" ]]; then
        local last_check=$(cat "$timestamp_file" 2>/dev/null || echo 0)
        local time_diff=$((current_time - last_check))
        
        if [[ $time_diff -ge $week_seconds ]]; then
            echo "\033[33m⚠️  It's been a week since your last update check.\033[0m"
            echo "\033[36mWould you like to run the update script? (y/N)\033[0m"
            read -q "REPLY?" && echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                "${HOME}/dotfiles/update.sh"
            fi
            echo "$current_time" >! "$timestamp_file"
        fi
    else
        # First time setup - create timestamp file
        echo "$current_time" >! "$timestamp_file"
    fi
}

# Run the check (but only in interactive shells)
[[ -o interactive ]] && _check_weekly_update

