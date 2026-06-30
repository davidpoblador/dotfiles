# shellcheck shell=bash
# Shared helpers for worktree-remove.sh and session-end-update-main.sh.
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
#   HOOK_DEBUG=1            — mirror log() and chatty subcommand output to
#                              the tty. Off by default so hook narration
#                              stays in the logfile and doesn't bleed into
#                              the Claude TUI of the running session that
#                              triggered the hook.
#   HOOK_DRY_RUN=1          — log destructive operations as "[dry-run] would ..."
#                              instead of executing them. Useful for debugging
#                              the cleanup loop without nuking real worktrees:
#                                  HOOK_DRY_RUN=1 echo "$payload" | worktree-remove.sh
#   HOOK_LOG_MAX_BYTES=N    — rotate today's log when it exceeds N bytes
#                              (default 5 MiB). Rotated files keep the
#                              "worktree-hooks-*.log" name so the existing
#                              age-based cleanup picks them up.

# Initialize logging state. Defines:
#   $LOGFILE    — daily log under /tmp; appended to in addition to stdout
#   $TARGET_TTY — $CLAUDE_INVOKER_TTY if set (so detached agent-team
#                 teammates can still reach the user's terminal), else
#                 /dev/tty
#   $OUT        — $TARGET_TTY when HOOK_DEBUG=1, else /dev/null (used to
#                 silence chatty subcommands while still capturing failures
#                 via log())
#   log()       — appends "$timestamp $tag $msg" to LOGFILE; also mirrors to
#                 $TARGET_TTY when HOOK_DEBUG=1
# $1: tag string included in every log line (e.g. "[create]" / "[remove]")
setup_logging() {
	# Promoted to a global so log() can read it after setup_logging returns
	# (bash has no closures — function bodies look up vars at call time).
	LOG_TAG="$1"
	LOGFILE="/tmp/worktree-hooks-$(date '+%Y-%m-%d').log"
	rotate_log_if_oversized "$LOGFILE" "${HOOK_LOG_MAX_BYTES:-5242880}"
	TARGET_TTY="${CLAUDE_INVOKER_TTY:-/dev/tty}"
	DRY_RUN="${HOOK_DRY_RUN:-0}"
	# Defined here, called from caller scope after we return — invisible to
	# static analysis, hence the disables for "unreachable" / "unused".
	# Default to logfile-only: Claude Code's hook contract is stdin=payload,
	# stdout=protocol, stderr=surfaced — writing to /dev/tty bypasses that
	# and bleeds into the running session's TUI. HOOK_DEBUG=1 opts back in.
	if [ "${HOOK_DEBUG:-0}" = "1" ]; then
		OUT="$TARGET_TTY"
		# shellcheck disable=SC2317,SC2329
		log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_TAG $*" | tee -a "$LOGFILE" >"$TARGET_TTY" 2>/dev/null || true; }
	else
		OUT=/dev/null
		# shellcheck disable=SC2317,SC2329
		log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_TAG $*" >> "$LOGFILE"; }
	fi
	# Always file-only, even under HOOK_DEBUG — for payload dumps and other
	# noise we never want on the tty.
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

# Print every registered worktree as "<path>\t<branch>", one per line, with the
# branch stripped of its refs/heads/ prefix (empty for detached/bare entries).
# Authoritative via `git worktree list --porcelain`, so namespaced worktree
# paths (e.g. .claude/worktrees/dig/<slug>) survive intact where a basename or
# fixed-depth glob would mangle them.
# $1: repo root
list_worktrees() {
	local repo="$1"
	git -C "$repo" worktree list --porcelain 2>/dev/null | awk '
		/^worktree / { if (wt != "") print wt "\t" b; wt = substr($0, 10); b = "" }
		/^branch /   { b = substr($0, 8); sub(/^refs\/heads\//, "", b) }
		END          { if (wt != "") print wt "\t" b }
	'
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
# working tree has uncommitted changes we reset only the index and preserve
# every locally-edited file; we --hard reset only when the tree was already
# clean. On a dirty tree we additionally sync forward the files the new
# commits changed that had no local edits, so a just-merged PR's own files
# don't linger as phantom "reversions" in the main checkout.
# Logs progress through the caller's log() — caller is responsible for the
# surrounding "✓ Fetching..." / "✓ up to date" announcements.
# $1: repo root  $2: branch name (no refs/heads/ prefix)
update_default_branch() {
	local repo="$1" branch="$2" was_clean=false old_head new_head
	if is_dry_run; then
		log "[dry-run] would fetch + fast-forward $branch in $repo"
		return 0
	fi
	if git -C "$repo" diff --quiet 2>/dev/null && git -C "$repo" diff --cached --quiet 2>/dev/null; then
		was_clean=true
	fi
	old_head=$(git -C "$repo" rev-parse HEAD 2>/dev/null || true)
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
		# A mixed reset advances HEAD + index to the new tip but never touches
		# the working tree, so files the new commits changed are left at their
		# old content and surface as phantom "reversions" of the just-merged
		# work. Sync exactly those files forward — but only the ones with no
		# local edits, so genuine in-progress work stays untouched.
		new_head=$(git -C "$repo" rev-parse HEAD 2>/dev/null || true)
		if [ -n "$old_head" ] && [ -n "$new_head" ] && [ "$old_head" != "$new_head" ]; then
			local f synced=0
			while IFS= read -r f; do
				[ -n "$f" ] || continue
				# Clean relative to the old tip means the working copy was never
				# edited locally; safe to fast-forward to the new index content.
				if git -C "$repo" diff --quiet "$old_head" -- "$f" 2>/dev/null; then
					git -C "$repo" checkout -- "$f" >"$OUT" 2>&1 && synced=$((synced + 1)) || true
				fi
			done < <(git -C "$repo" diff --name-only "$old_head" "$new_head" 2>/dev/null)
			[ "$synced" -gt 0 ] && log "✓ Synced $synced cleanly-merged file(s) forward, preserved local edits"
		fi
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
#
# The local branch carries the create-hook's "worktree-" prefix, but the PR
# head on GitHub is the de-prefixed name the push used (e.g. local
# worktree-dig/<slug> vs head dig/<slug>). Query both heads; this only ever
# confirms a genuinely merged PR, so it never loosens the safety guard.
# $1: repo root  $2: branch name
merged_pr_for_branch() {
	local repo="$1" branch="$2" head pr
	for head in "$branch" "${branch#worktree-}"; do
		pr=$(project_gh "$repo" pr list --head "$head" --state merged --json number --jq '.[0].number' 2>/dev/null || true)
		if [ -n "$pr" ]; then
			echo "$pr"
			return 0
		fi
		[ "$branch" = "${branch#worktree-}" ] && break
	done
	# Always succeed: callers run under `set -e` and use this in bare
	# assignments, relying on the empty-string output (not the exit code).
	return 0
}

# Returns 0 (true) if $branch's work is already in $base — squash-merged or
# rebased — and 1 if any of it is genuinely unique to $branch, or on command
# failure (conservative: prefer "not merged" on uncertainty).
#
# Two checks, both remote-agnostic so the hooks can detect merged work without
# GitHub:
#
#   1. `git cherry $base $branch` matches commits one-by-one by patch-id,
#      prefixing the missing ones with "+". This catches rebase merges and the
#      squash of a *single* commit. But a squash of N commits collapses them
#      into one union-diff commit on $base, so no individual patch-id matches
#      and every branch commit shows as "+".
#
#   2. For that multi-commit squash, compare the patch-id of the branch's whole
#      diff (merge-base..branch) against each commit added to $base since the
#      branch diverged. The squash commit carries exactly that union diff, so
#      its patch-id matches. patch-id ignores line offsets, so $base advancing
#      underneath the branch doesn't defeat it.
# $1: repo root  $2: base ref  $3: branch name
branch_is_squash_merged_into() {
	local repo="$1" base="$2" branch="$3" out mb branch_pid c cpid
	out=$(git -C "$repo" cherry "$base" "$branch" 2>/dev/null) || return 1
	grep -q '^+ ' <<< "$out" || return 0

	mb=$(git -C "$repo" merge-base "$base" "$branch" 2>/dev/null) || return 1
	branch_pid=$(git -C "$repo" diff "$mb" "$branch" 2>/dev/null | git -C "$repo" patch-id --stable 2>/dev/null | awk '{print $1}')
	[ -n "$branch_pid" ] || return 1
	for c in $(git -C "$repo" rev-list -n 100 "$base" "^$mb" 2>/dev/null); do
		cpid=$(git -C "$repo" show "$c" 2>/dev/null | git -C "$repo" patch-id --stable 2>/dev/null | awk '{print $1}')
		[ "$cpid" = "$branch_pid" ] && return 0
	done
	return 1
}

# Best-effort removal of a worktree directory and its branch.
#   1. Pre-delete heavy untracked dirs (.venv, node_modules) so `git worktree
#      remove --force` doesn't trip over them.
#   2. Run `git worktree remove --force`; on failure, prune git's bookkeeping
#      and warn — but leave the directory alone. Matches Claude Code 2.1.147's
#      built-in cleanup behavior, which dropped the rm -rf fallback to avoid
#      destroying gitignored or in-progress files when remove fails for an
#      unexpected reason.
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
		log "⚠ git worktree remove --force failed for $wt_dir; leaving directory in place"
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
#   - its work is already in $base_ref (squash/rebase merged) or a merged PR
#     exists for it — the same check the targeted remove path uses, so the
#     sweep mops up merged worktrees the explicit removal skipped (remote branch
#     lingering, or pushed under a de-prefixed head), OR
#   - its branch had an upstream and the remote branch is now gone (and, if
#     $require_pr=yes, a merged PR exists for it), OR
#   - it was never pushed, has no unique commits beyond $base_ref, and was
#     created more than 24 hours ago.
# Worktrees with unpushed, unmerged unique commits are always preserved.
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

	local stale_dir stale_name stale_branch upstream has_upstream should_clean reason
	local merged_pr wt_created age_hours unique_commits
	local removed=0 kept=0 scanned=0
	# Enumerate worktrees authoritatively from git rather than globbing a fixed
	# depth, so namespaced worktrees (.claude/worktrees/dig/<slug>) are visible
	# and their real branch (with slashes) comes straight from git.
	while IFS=$'\t' read -r stale_dir stale_branch; do
		case "$stale_dir" in
			"$dir"/*) ;;
			*) continue ;;
		esac
		[ -d "$stale_dir" ] && [ -n "$stale_branch" ] || continue
		stale_name="${stale_dir#"$dir"/}"
		[ "$stale_name" = "$skip" ] && continue
		scanned=$((scanned + 1))

		# A branch made with `git worktree add -b <name> origin/<default>`
		# inherits origin/<default> as its upstream via branch.autoSetupMerge
		# (on by default). That is NOT evidence the branch was ever pushed —
		# so only count an upstream that points at the branch's own remote ref.
		# The push may target a de-prefixed head (worktree-dig/<slug> pushes to
		# origin/dig/<slug>), so accept that ref too. Otherwise a fresh,
		# never-pushed worktree takes the "pushed then remote gone" path, looks
		# squash-merged (no unique commits vs base), and gets deleted mid-run.
		upstream=$(git -C "$repo" for-each-ref --format='%(upstream)' "refs/heads/$stale_branch" 2>/dev/null)
		if [ "$upstream" = "refs/remotes/origin/$stale_branch" ] \
			|| [ "$upstream" = "refs/remotes/origin/${stale_branch#worktree-}" ]; then
			has_upstream="$upstream"
		else
			has_upstream=""
		fi
		should_clean=false
		reason=""

		# Primary check, mirroring the targeted remove path: if the branch's
		# work is already in $base_ref (squash/rebase merged) or a merged PR
		# exists, it's safe to clean regardless of upstream/remote state. This
		# catches merged worktrees that linger because their remote branch was
		# never deleted, or because they pushed under a de-prefixed head, so the
		# upstream/age heuristics below never opened the gate. Guard on
		# unique_commits>0: branch_is_squash_merged_into reports a zero-commit
		# branch as merged (empty `git cherry`), which would sweep a fresh
		# worktree that has no work yet.
		unique_commits=$(unique_commits_against "$repo" "$base_ref" "$stale_branch")
		if [ "$unique_commits" -gt 0 ]; then
			if branch_is_squash_merged_into "$repo" "$base_ref" "$stale_branch"; then
				should_clean=true
				reason="all commits already in $base_ref (squash/rebase merged)"
			else
				merged_pr=$(merged_pr_for_branch "$repo" "$stale_branch")
				if [ -n "$merged_pr" ]; then
					should_clean=true
					reason="PR #$merged_pr merged"
				fi
			fi
		fi

		# Fallback heuristics, only when the merge check above didn't already
		# decide. These guard never-pushed local work from being swept.
		if [ "$should_clean" != true ] && [ -n "$has_upstream" ]; then
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
		elif [ "$should_clean" != true ]; then
			# Never pushed. Only clean if it's old AND has no unique commits,
			# so we never silently throw away in-progress local work. A 0
			# timestamp means the creation time is unknown (no reflog); treat
			# that as too-young-to-clean rather than infinitely old, so missing
			# data never lets us delete a worktree.
			wt_created=$(branch_created_at "$repo" "$stale_branch")
			age_hours=$(( ($(date +%s) - wt_created) / 3600 ))
			if [ "$wt_created" -le 0 ]; then
				log "⏭ Keeping stale worktree: $stale_name (unknown creation time)"
			elif [ "$age_hours" -ge 24 ]; then
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
	done < <(list_worktrees "$repo")
	if [ "$scanned" -gt 0 ]; then
		log "✓ Cleanup loop: scanned $scanned, removed $removed, kept $kept"
	fi
}
