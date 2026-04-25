# shellcheck shell=bash
# Shared helpers for worktree-create.sh and worktree-remove.sh.
# Sourced, not executed.
#
# Conventions:
#   - All helpers take $repo (the main repo root) as the first arg explicitly,
#     so callers control the target rather than relying on cwd.
#   - Helpers depend on the caller having defined log() and $OUT, both set up
#     by setup_logging. We rely on bash dynamic scoping for that, which keeps
#     each helper signature small and readable.

# Initialize logging state. Defines:
#   $LOGFILE — daily log under /tmp; appended to in addition to stdout
#   $OUT     — /dev/tty when HOOK_DEBUG=1, else /dev/null (used to silence
#              chatty subcommands while still capturing failures via log())
#   log()    — prints "$timestamp $tag $msg" to stderr-via-tty and LOGFILE
# $1: tag string included in every log line (e.g. "[create]" / "[remove]")
setup_logging() {
	# Promoted to a global so log() can read it after setup_logging returns
	# (bash has no closures — function bodies look up vars at call time).
	LOG_TAG="$1"
	LOGFILE="/tmp/worktree-hooks-$(date '+%Y-%m-%d').log"
	if [ "${HOOK_DEBUG:-0}" = "1" ]; then
		OUT=/dev/tty
	else
		OUT=/dev/null
	fi
	# shellcheck disable=SC2317  # invoked from caller scope
	log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_TAG $*" | tee -a "$LOGFILE" >/dev/tty 2>/dev/null || true; }
}

# Print the original repo's working-tree path, even when called from inside a
# worktree. CLAUDE_PROJECT_DIR points at the worktree when Claude runs there,
# but `git worktree list --porcelain` always returns the main worktree first.
# Falls back to the input path if `git worktree list` returns nothing.
# $1: a path inside the repo (typically $CLAUDE_PROJECT_DIR)
resolve_repo_root() {
	local from="$1" root
	root=$(git -C "$from" worktree list --porcelain 2>/dev/null | head -1 | sed 's/^worktree //')
	echo "${root:-$from}"
}

# Print the repo's default branch name (no refs/ prefix).
# Prefers origin/HEAD's symbolic ref, falls back to local main, then master.
# Empty output means no default branch could be determined.
# $1: repo root
detect_default_branch() {
	local repo="$1" branch
	branch=$(git -C "$repo" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@') || true
	if [ -z "$branch" ]; then
		if git -C "$repo" show-ref --verify --quiet refs/heads/main 2>/dev/null; then
			branch="main"
		elif git -C "$repo" show-ref --verify --quiet refs/heads/master 2>/dev/null; then
			branch="master"
		fi
	fi
	echo "$branch"
}

# Fast-forward $branch in $repo to origin's tip. Always safe to call: if the
# working tree has uncommitted changes we only reset the index (preserving
# the user's edits); we --hard reset only when the tree was already clean.
# Logs progress through the caller's log() — caller is responsible for the
# surrounding "✓ Fetching..." / "✓ up to date" announcements.
# $1: repo root  $2: branch name (no refs/heads/ prefix)
update_default_branch() {
	local repo="$1" branch="$2" was_clean=false
	if git -C "$repo" diff --quiet 2>/dev/null && git -C "$repo" diff --cached --quiet 2>/dev/null; then
		was_clean=true
	fi
	git -C "$repo" fetch origin "$branch" >"$OUT" 2>&1 || log "⚠ fetch failed, continuing with local $branch"
	git -C "$repo" update-ref "refs/heads/$branch" "refs/remotes/origin/$branch" 2>"$OUT" \
		|| log "⚠ update-ref failed, continuing with local $branch"
	# update-ref moves the ref but leaves the index + working tree stale, so a
	# reset is required to match. Only --hard when we know we won't lose work.
	if [ "$was_clean" = true ]; then
		git -C "$repo" reset --hard --quiet >"$OUT" 2>&1 || true
	else
		git -C "$repo" reset --quiet >"$OUT" 2>&1 || true
		log "⚠ Working tree had local changes, preserved them (index reset only)"
	fi
}

# Print the unix timestamp of the oldest reflog entry for $branch — i.e. the
# moment the branch was first written. Returns 0 if reflog is empty/missing.
#
# WHY NOT %ct: %ct is the *commit* timestamp at the branch tip, which has no
# relation to when the branch ref itself was created. A worktree branched off
# a 3-day-old main commit would falsely appear "3 days old" to age checks.
# %gd with --date=unix gives the reflog entry's own time as `branch@{<ts>}`.
# $1: repo root  $2: branch name (no refs/heads/ prefix)
branch_created_at() {
	local repo="$1" branch="$2" ts
	ts=$(git -C "$repo" reflog show --date=unix --format='%gd' "$branch" 2>/dev/null \
		| tail -1 | sed -E 's/.*@\{([0-9]+)\}/\1/')
	echo "${ts:-0}"
}

# Run gh against $repo's remote configuration, regardless of cwd. Setting
# GIT_DIR makes gh resolve owner/repo from the repo's git config rather than
# its cwd, so it works correctly across forks, renames, and different orgs.
# $1: repo root  $@: gh args (e.g. pr list --head ... --state merged)
project_gh() {
	local repo="$1"; shift
	GIT_DIR="$repo/.git" gh "$@"
}

# Best-effort removal of a worktree directory and its branch.
#   1. Pre-delete heavy untracked dirs (.venv, node_modules) so `git worktree
#      remove --force` doesn't trip over them.
#   2. Run `git worktree remove --force`; on failure, fall back to rm -rf +
#      `worktree prune` so we never leave a half-removed worktree.
#   3. Delete the local branch if it still exists.
#   4. Clear core.worktree if it pointed at the removed dir (an old git bug
#      could leave that pointer dangling).
# $1: repo root  $2: worktree dir (with or without trailing slash)
# $3: branch name (no refs/heads/ prefix)
remove_worktree_branch() {
	local repo="$1" wt_dir="$2" branch="$3" configured
	rm -rf "$wt_dir/.venv" "$wt_dir/node_modules"
	git -C "$repo" worktree remove --force "$wt_dir" >"$OUT" 2>&1 || {
		rm -rf "$wt_dir"
		git -C "$repo" worktree prune >"$OUT" 2>&1 || true
	}
	if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
		git -C "$repo" branch -D "$branch" >"$OUT" 2>&1 || true
	fi
	configured=$(git -C "$repo" config core.worktree 2>/dev/null || true)
	if [ "$configured" = "$wt_dir" ] || [ "$configured" = "${wt_dir%/}" ]; then
		git -C "$repo" config --unset core.worktree >"$OUT" 2>&1 || true
		log "✓ Cleared stale core.worktree for $(basename "$wt_dir")"
	fi
}

# Iterate over $repo/.claude/worktrees/* and remove any that are stale.
# A worktree is stale when:
#   - its branch had an upstream and the remote branch is now gone (and, if
#     $require_pr=yes, a merged PR exists for it), OR
#   - it was never pushed, has no unique commits beyond $base_ref, and was
#     created more than 24 hours ago.
# Worktrees with unpushed unique commits are always preserved.
#
# $1 repo            — repo root
# $2 base_ref        — branch the unique-commit count is measured against,
#                      typically DEFAULT_BRANCH or the just-computed BASE_REF
# $3 skip_name       — worktree name to skip (the current/just-removed one)
# $4 require_pr      — "yes" requires a merged PR before cleaning a worktree
#                      whose remote branch is gone (defensive — guards against
#                      remote branches deleted without merging); "no" trusts
#                      the absent remote and cleans unconditionally
clean_stale_worktrees() {
	local repo="$1" base_ref="$2" skip="$3" require_pr="$4"
	local dir="$repo/.claude/worktrees"
	[ -d "$dir" ] || return 0
	git -C "$repo" fetch origin --prune >"$OUT" 2>&1 || true

	local stale_dir stale_name stale_branch has_upstream should_clean reason
	local merged_pr wt_created age_hours unique_commits
	for stale_dir in "$dir"/*/; do
		[ -d "$stale_dir" ] || continue
		stale_name=$(basename "$stale_dir")
		stale_branch="worktree-$stale_name"
		[ "$stale_name" = "$skip" ] && continue

		has_upstream=$(git -C "$repo" for-each-ref --format='%(upstream)' "refs/heads/$stale_branch" 2>/dev/null)
		should_clean=false
		reason=""

		if [ -n "$has_upstream" ]; then
			# Pushed at some point. If the remote branch is gone, the work is
			# very likely merged — but verify with a PR check when require_pr.
			if ! git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/$stale_branch" 2>/dev/null; then
				if [ "$require_pr" = "yes" ]; then
					merged_pr=$(project_gh "$repo" pr list --head "$stale_branch" --state merged --json number --jq '.[0].number' 2>/dev/null || true)
					if [ -n "$merged_pr" ]; then
						should_clean=true
						reason="remote branch gone, PR #$merged_pr merged"
					else
						log "⏭ Keeping worktree: $stale_name (remote branch gone but no merged PR found)"
					fi
				else
					should_clean=true
					reason="remote branch gone"
				fi
			fi
		else
			# Never pushed. Only clean if it's old AND has no unique commits,
			# so we never silently throw away in-progress local work.
			wt_created=$(branch_created_at "$repo" "$stale_branch")
			age_hours=$(( ($(date +%s) - wt_created) / 3600 ))
			if [ "$age_hours" -ge 24 ]; then
				unique_commits=$(git -C "$repo" rev-list --count "$base_ref".."$stale_branch" 2>/dev/null || echo 0)
				if [ "$unique_commits" -eq 0 ]; then
					should_clean=true
					reason="no upstream, no unique commits, ${age_hours}h old"
				else
					log "⏭ Keeping stale worktree: $stale_name (${age_hours}h old but has $unique_commits unpushed commit(s))"
				fi
			fi
		fi

		if [ "$should_clean" = true ]; then
			log "✓ Cleaning stale worktree: $stale_name ($reason)"
			remove_worktree_branch "$repo" "$stale_dir" "$stale_branch"
		fi
	done
}
