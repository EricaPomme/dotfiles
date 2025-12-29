# Update selected git repos quietly in the background.
(
	repos=(
		"$HOME/.ssh"
		"$HOME/dotfiles"
	)

	command -v git >/dev/null 2>&1 || exit 0

	for repo_dir in "${repos[@]}"; do
		# Skip if not a repo directory.
		[ -d "$repo_dir/.git" ] || git -C "$repo_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || continue

		# Require a clean worktree and an upstream to compare against.
		git -C "$repo_dir" diff-index --quiet HEAD -- || continue
		upstream_ref=$(git -C "$repo_dir" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null) || continue

		# Fetch and pull only when behind.
		git -C "$repo_dir" fetch --quiet >/dev/null 2>&1 || continue
		behind_count=$(git -C "$repo_dir" rev-list --count "HEAD..$upstream_ref" 2>/dev/null || printf '0')
		[ "${behind_count:-0}" -gt 0 ] || continue
		git -C "$repo_dir" pull --quiet --ff-only >/dev/null 2>&1
	done
) >/dev/null 2>&1 &
