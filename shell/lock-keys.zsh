# Module: lock-keys.zsh
# Provides: lock_keys function + numlock/capslock/scrolllock aliases
# Usage:
#   lock_keys {num|caps|scroll} [on|off]
#   numlock [on|off]       # forwards to lock_keys num ...
#   capslock [on|off]      # forwards to lock_keys caps ...
#   scrolllock [on|off]    # forwards to lock_keys scroll ...
#
# Exit codes:
#   0 success
#   1 invalid usage or unknown key
#   2 xset not found or X11 DISPLAY not available
#   3 could not determine current state
#   4 invalid state (not on/off)
#   5 failed to set state via xset

lock_keys() {
    emulate -L zsh

    local -A _lk_map
    _lk_map=(
        num    "Num Lock"
        caps   "Caps Lock"
        scroll "Scroll Lock"
    )

    local key="${1:-}"
    local req="${2:-}"

    if [[ -z "$key" || -z "${_lk_map[$key]}" ]]; then
        print -u2 -- "Usage: lock_keys {num|caps|scroll} [on|off]"
        return 1
    fi

    if ! command -v xset >/dev/null 2>&1; then
        print -u2 -- "lock_keys: xset not found"
        return 2
    fi

    if [[ -z "${DISPLAY:-}" ]]; then
        print -u2 -- "lock_keys: DISPLAY not set (no X11)"
        return 2
    fi

    local xname="${_lk_map[$key]}"
    local target=""

    if [[ -n "$req" ]]; then
        case "${req:l}" in
            on|off) target="${req:l}" ;;
            *) print -u2 -- "lock_keys: invalid state '$req' (use on|off)"; return 4 ;;
        esac
    else
        # Determine current state via xset q
        local current
        current="$(xset q 2>/dev/null | sed -nE "s/.*${xname}:[[:space:]]*(on|off).*/\1/p" | head -n1)"
        current="${current:l}"

        if [[ "$current" != "on" && "$current" != "off" ]]; then
            print -u2 -- "lock_keys: failed to determine current state for ${xname}"
            return 3
        fi

        target="$([[ "$current" == "on" ]] && print off || print on)"
    fi

    if [[ "$target" == "on" ]]; then
        if ! xset led named "$xname" >/dev/null 2>&1; then
            print -u2 -- "lock_keys: failed to turn on ${xname}"
            return 5
        fi
    else
        if ! xset -led named "$xname" >/dev/null 2>&1; then
            print -u2 -- "lock_keys: failed to turn off ${xname}"
            return 5
        fi
    fi

    return 0
}

# Convenience aliases; additional args are forwarded by alias expansion.
alias numlock='lock_keys num'
alias capslock='lock_keys caps'
alias scrolllock='lock_keys scroll'
