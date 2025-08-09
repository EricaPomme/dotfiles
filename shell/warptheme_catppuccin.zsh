[[ -n ${CATPPUCCIN_WARP_LOADED} ]] && return
CATPPUCCIN_WARP_LOADED=1

install_catppuccin_warp_themes() {
    local themes_dir="${HOME}/.warp/themes"
    local themes=(
        "catppuccin_macchiato.yml"
        "catppuccin_frappe.yml"
        "catppuccin_latte.yml"
        "catppuccin_mocha.yml"
    )
    
    # Create themes directory if it doesn't exist
    if [[ ! -d "$themes_dir" ]]; then
        mkdir -p "$themes_dir"
    fi
    
    # Check and download missing themes
    local updated=false
    local base_url="https://raw.githubusercontent.com/catppuccin/warp/main/themes"
    
    for theme in "${themes[@]}"; do
        local theme_path="$themes_dir/$theme"
        
        if [[ ! -f "$theme_path" ]]; then
            echo -e "\033[36mDownloading Catppuccin theme: $theme...\033[0m"
            
            if command -v curl >/dev/null 2>&1; then
                if curl -fsSL "$base_url/$theme" -o "$theme_path"; then
                    echo -e "\033[32m Downloaded: $theme\033[0m"
                    updated=true
                else
                    echo -e "\033[31m Failed to download theme: $theme\033[0m"
                fi
            elif command -v wget >/dev/null 2>&1; then
                if wget -q "$base_url/$theme" -O "$theme_path"; then
                    echo -e "\033[32m Downloaded: $theme\033[0m"
                    updated=true
                else
                    echo -e "\033[31m Failed to download theme: $theme\033[0m"
                fi
            else
                echo -e "\033[31m Neither curl nor wget found. Cannot download themes.\033[0m"
                return 1
            fi
        fi
    done
    
    if [[ "$updated" == true ]]; then
        echo -e "\033[33m Catppuccin themes for Warp have been updated. Restart Warp to see new themes.\033[0m"
    else
        echo -e "\033[32m All Catppuccin themes are already installed.\033[0m"
    fi
}
