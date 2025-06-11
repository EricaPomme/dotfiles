# Check for upstream git ahead of us
autoload -U add-zsh-hook
GIT_PULL_NUDGE_CACHE_TIMEOUT=60
typeset -gA GIT_PULL_NUDGE_LAST_CHECKED

git_pull_nudge() {
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        return
    fi

    local repo_path
    repo_path=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -z "$repo_path" ]]; then
        return
    fi

    # Does this repo have at least one remote?
    if [[ -z "$(git remote)" ]]; then
        return
    fi

    # Check cooldown
    local now
    now=$(date +%s)
    local last_checked=${GIT_PULL_NUDGE_LAST_CHECKED[$repo_path]:-0}
    local elapsed=$(( now - last_checked ))

    if (( elapsed < GIT_PULL_NUDGE_CACHE_TIMEOUT )); then
        return
    fi

    # Update last checked timestamp
    GIT_PULL_NUDGE_LAST_CHECKED[$repo_path]=$now

    # Safe remote update
    git remote update &>/dev/null

    local git_status_output
    git_status_output=$(git status -sb 2>/dev/null)

    if echo "$git_status_output" | grep -q '\[behind'; then
        echo -e "\e[33m🔄  Repo is behind remote! Consider running 'git pull'.\e[0m"
    else
        echo -e "\e[32m✅  Repo is up to date with remote.\e[0m"
    fi
}

add-zsh-hook chpwd git_pull_nudge