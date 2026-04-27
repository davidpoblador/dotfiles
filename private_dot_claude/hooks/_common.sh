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
#
# Environment variables read:
#   HOOK_DEBUG=1            — surface chatty subcommand output on the tty.
#   HOOK_DRY_RUN=1          — log destructive operations as "[dry-run] would ..."
#                              instead of executing them. Useful for debugging
#                              the cleanup loop without nuking real worktrees:
#                                  HOOK_DRY_RUN=1 echo "$payload" | worktree-create.sh
#   HOOK_LOG_MAX_BYTES=N    — rotate today's log when it exceeds N bytes
#                              (default 5 MiB). Rotated files keep the
#                              "worktree-hooks-*.log" name so the existing
#                              age-based cleanup picks them up.

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
	rotate_log_if_oversized "$LOGFILE" "${HOOK_LOG_MAX_BYTES:-5242880}"
	if [ "${HOOK_DEBUG:-0}" = "1" ]; then
		OUT=/dev/tty
	else
		OUT=/dev/null
	fi
	DRY_RUN="${HOOK_DRY_RUN:-0}"
	# Defined here, called from caller scope after we return — invisible to
	# static analysis, hence the disables for "unreachable" / "unused".
	# shellcheck disable=SC2317,SC2329
	log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_TAG $*" | tee -a "$LOGFILE" >/dev/tty 2>/dev/null || true; }
	# Same shape, file-only — for verbose lines we don't want on screen.
	# shellcheck disable=SC2317,SC2329
	log_quiet() { echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_TAG $*" >> "$LOGFILE"; }
}

# True when HOOK_DRY_RUN=1. Used by destructive helpers to short-circuit.
is_dry_run() { [ "${DRY_RUN:-0}" = "1" ]; }

# Rename $logfile out of the way if it's larger than $max_bytes, so today's
# log starts fresh. Rotated files keep the "worktree-hooks-*.log" pattern
# (suffix is the current HHMMSS) so the daily age-based cleanup catches them.
# Silent on the no-op path; uses BSD stat first, falls back to GNU.
# $1: logfile path  $2: max bytes
rotate_log_if_oversized() {
	local logfile="$1" max_bytes="$2" size
	[ -f "$logfile" ] || return 0
	size=$(stat -f %z "$logfile" 2>/dev/null || stat -c %s "$logfile" 2>/dev/null || echo 0)
	if [ "$size" -gt "$max_bytes" ]; then
		mv "$logfile" "${logfile%.log}-$(date +%H%M%S).log" 2>/dev/null || true
	fi
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
	if is_dry_run; then
		log "[dry-run] would fetch + fast-forward $branch in $repo"
		return 0
	fi
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

# Print the count of commits in $branch not yet reachable from $base. Returns
# 0 if either ref is missing/empty, so callers can use the result directly in
# numeric comparisons without extra guards.
# $1: repo root  $2: base ref  $3: branch name
unique_commits_against() {
	local repo="$1" base="$2" branch="$3"
	git -C "$repo" rev-list --count "$base".."$branch" 2>/dev/null || echo 0
}

# Print the merged-PR number for $branch, or empty if none. Squash merges
# produce different commit SHAs, so a "0 unique commits" check alone can
# miss merged work — this is the secondary check.
# $1: repo root  $2: branch name
merged_pr_for_branch() {
	local repo="$1" branch="$2"
	project_gh "$repo" pr list --head "$branch" --state merged --json number --jq '.[0].number' 2>/dev/null || true
}

# Returns 0 (true) if every commit in $branch has an equivalent already in
# $base by patch-id — i.e., the branch was squash-merged or rebased into
# $base. Returns 1 if any commit is genuinely unique to $branch, or if the
# command fails (conservative: prefer "not merged" on uncertainty).
#
# `git cherry $base $branch` lists commits in $branch not in $base, prefixed
# with "+" (no patch-id match in $base) or "-" (patch-id present in $base).
# Any "+" line means real divergence; all-"-" or empty output means merged.
#
# This is the remote-agnostic equivalent of "is there a merged PR?", so the
# hooks no longer need GitHub to detect squash-merged work.
# $1: repo root  $2: base ref  $3: branch name
branch_is_squash_merged_into() {
	local repo="$1" base="$2" branch="$3" out
	out=$(git -C "$repo" cherry "$base" "$branch" 2>/dev/null) || return 1
	! grep -q '^+ ' <<< "$out"
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
	if is_dry_run; then
		log "[dry-run] would rm -rf $wt_dir/{.venv,node_modules} and remove worktree $wt_dir"
		log "[dry-run] would delete branch $branch (if present)"
		return 0
	fi
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

# Sanitize an absolute path the same way Claude does for project config dirs:
# / -> -, . -> -. So /foo/.claude/worktrees/abc becomes
# -foo--claude-worktrees-abc. Trailing slashes are stripped first so callers
# can pass directories with or without one.
# $1: absolute path
sanitize_path() {
	local p="${1%/}"
	echo "$p" | sed 's|/|-|g; s|\.|-|g'
}

# Returns 0 (true) if any live Claude session has its cwd inside $wt_dir.
# Reads ~/.claude/sessions/<PID>.json files (Claude writes one per running
# session) and verifies the PID is alive — stale files survive crashes, so the
# liveness check is required.
#
# When $exclude_session is non-empty, sessions with that sessionId are skipped.
# Used by the primary remove path to avoid self-blocking on the very session
# that triggered the ExitWorktree hook.
#
# $1: worktree directory  $2: optional sessionId to exclude
worktree_has_active_session() {
	local wt_dir="${1%/}" exclude_session="${2:-}" sessions_dir="$HOME/.claude/sessions"
	local f cwd pid sid
	[ -d "$sessions_dir" ] || return 1
	for f in "$sessions_dir"/*.json; do
		[ -f "$f" ] || continue
		cwd=$(jq -r '.cwd // empty' "$f" 2>/dev/null)
		pid=$(jq -r '.pid // empty' "$f" 2>/dev/null)
		sid=$(jq -r '.sessionId // empty' "$f" 2>/dev/null)
		[ -n "$cwd" ] && [ -n "$pid" ] || continue
		if [ -n "$exclude_session" ] && [ "$sid" = "$exclude_session" ]; then
			continue
		fi
		case "$cwd" in
			"$wt_dir"|"$wt_dir"/*) ;;
			*) continue ;;
		esac
		kill -0 "$pid" 2>/dev/null && return 0
	done
	return 1
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
	local removed=0 kept=0 scanned=0
	for stale_dir in "$dir"/*/; do
		[ -d "$stale_dir" ] || continue
		stale_name=$(basename "$stale_dir")
		stale_branch="worktree-$stale_name"
		[ "$stale_name" = "$skip" ] && continue
		scanned=$((scanned + 1))

		has_upstream=$(git -C "$repo" for-each-ref --format='%(upstream)' "refs/heads/$stale_branch" 2>/dev/null)
		should_clean=false
		reason=""

		if [ -n "$has_upstream" ]; then
			# Pushed at some point. If the remote branch is gone, the work is
			# very likely merged. Verify in this order:
			#   1. git cherry — portable, catches squash/rebase merges
			#   2. gh pr list — GitHub-only, catches edge cases (rare)
			# When require_pr=no we trust an absent remote outright.
			if ! git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/$stale_branch" 2>/dev/null; then
				if branch_is_squash_merged_into "$repo" "$base_ref" "$stale_branch"; then
					should_clean=true
					reason="remote branch gone, all commits already in $base_ref"
				elif [ "$require_pr" = "yes" ]; then
					merged_pr=$(merged_pr_for_branch "$repo" "$stale_branch")
					if [ -n "$merged_pr" ]; then
						should_clean=true
						reason="remote branch gone, PR #$merged_pr merged"
					else
						log "⏭ Keeping worktree: $stale_name (remote branch gone but no merge evidence)"
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
				unique_commits=$(unique_commits_against "$repo" "$base_ref" "$stale_branch")
				if [ "$unique_commits" -eq 0 ]; then
					should_clean=true
					reason="no upstream, no unique commits, ${age_hours}h old"
				else
					log "⏭ Keeping stale worktree: $stale_name (${age_hours}h old but has $unique_commits unpushed commit(s))"
				fi
			fi
		fi

		if [ "$should_clean" = true ]; then
			if worktree_has_active_session "$stale_dir"; then
				log "⏭ Keeping worktree: $stale_name (live Claude session in this dir)"
				kept=$((kept + 1))
			else
				log "→ Cleaning stale worktree: $stale_name ($reason)"
				remove_worktree_branch "$repo" "$stale_dir" "$stale_branch"
				removed=$((removed + 1))
			fi
		else
			kept=$((kept + 1))
		fi
	done
	if [ "$scanned" -gt 0 ]; then
		log "✓ Cleanup loop: scanned $scanned, removed $removed, kept $kept"
	fi
}
