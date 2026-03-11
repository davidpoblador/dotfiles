#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)

LOGFILE="/tmp/worktree-hooks-$(date '+%Y-%m-%d').log"

# WorktreeRemove payload has worktree_path (not name)
NAME=$(echo "$INPUT" | jq -r '.worktree_path // empty' | xargs basename 2>/dev/null || true)
if [ -z "$NAME" ]; then
	echo "[$(date '+%H:%M:%S')] [remove] ERROR: Could not extract worktree name" >> "$LOGFILE"
	exit 0
fi

WORKTREE_DIR="$CLAUDE_PROJECT_DIR/.claude/worktrees/$NAME"
BRANCH="worktree-$NAME"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [remove] $*" | tee -a "$LOGFILE" >/dev/tty 2>/dev/null || true; }
if [ "${HOOK_DEBUG:-0}" = "1" ]; then
	OUT=/dev/tty
else
	OUT=/dev/null
fi

echo "" >> "$LOGFILE"
log "--- WorktreeRemove: $NAME (branch: $BRANCH) ---"
echo "  payload: $INPUT" >> "$LOGFILE"

# --- determine default branch (needed for safety checks) ---
DEFAULT_BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@') || true
if [ -z "$DEFAULT_BRANCH" ]; then
	if git -C "$CLAUDE_PROJECT_DIR" show-ref --verify --quiet refs/heads/main 2>/dev/null; then
		DEFAULT_BRANCH="main"
	elif git -C "$CLAUDE_PROJECT_DIR" show-ref --verify --quiet refs/heads/master 2>/dev/null; then
		DEFAULT_BRANCH="master"
	fi
fi

# Helper: run gh with GIT_DIR so it resolves the repo from git remote config
# (handles forks, renames, different org names reliably)
project_gh() { GIT_DIR="$CLAUDE_PROJECT_DIR/.git" gh "$@"; }

# --- check if the branch has unmerged work before removing ---
SAFE_TO_REMOVE=true

if git -C "$CLAUDE_PROJECT_DIR" show-ref --verify --quiet "refs/heads/$BRANCH" 2>/dev/null; then
	unique_commits=$(git -C "$CLAUDE_PROJECT_DIR" rev-list --count "$DEFAULT_BRANCH".."$BRANCH" 2>/dev/null || echo 0)
	if [ "$unique_commits" -gt 0 ]; then
		# Branch has unique commits. Check if a merged PR exists (squash merges produce
		# different SHAs, so rev-list alone can't detect merged work).
		merged_pr=$(project_gh pr list --head "$BRANCH" --state merged --json number --jq '.[0].number' 2>/dev/null || true)
		if [ -n "$merged_pr" ]; then
			log "✓ Branch $BRANCH has $unique_commits local commit(s) but PR #$merged_pr was merged, safe to remove"
		else
			SAFE_TO_REMOVE=false
			log "⚠ Branch $BRANCH has $unique_commits unmerged commit(s) and no merged PR, preserving worktree"
		fi
	fi
fi

if [ "$SAFE_TO_REMOVE" = true ]; then
	# --- remove the worktree ---
	if [ -d "$WORKTREE_DIR" ]; then
		# Remove heavy untracked dirs that cause git worktree remove to fail
		rm -rf "$WORKTREE_DIR/.venv" "$WORKTREE_DIR/node_modules"
		git -C "$CLAUDE_PROJECT_DIR" worktree remove --force "$WORKTREE_DIR" >$OUT 2>&1 || {
			log "⚠ git worktree remove failed, cleaning up manually"
			rm -rf "$WORKTREE_DIR"
			git -C "$CLAUDE_PROJECT_DIR" worktree prune >$OUT 2>&1 || true
		}
		log "✓ Removed worktree: $NAME"
	else
		log "⚠ Worktree directory not found: $WORKTREE_DIR"
		git -C "$CLAUDE_PROJECT_DIR" worktree prune >$OUT 2>&1 || true
	fi

	# --- delete the local branch ---
	if git -C "$CLAUDE_PROJECT_DIR" show-ref --verify --quiet "refs/heads/$BRANCH" 2>/dev/null; then
		git -C "$CLAUDE_PROJECT_DIR" branch -D "$BRANCH" >$OUT 2>&1 || {
			log "⚠ Failed to delete branch $BRANCH"
		}
		log "✓ Deleted branch: $BRANCH"
	fi
fi

# --- update main ---
if [ -n "$DEFAULT_BRANCH" ]; then
	# Check if working tree is clean BEFORE moving the ref
	WAS_CLEAN=false
	if git -C "$CLAUDE_PROJECT_DIR" diff --quiet 2>/dev/null && \
	   git -C "$CLAUDE_PROJECT_DIR" diff --cached --quiet 2>/dev/null; then
		WAS_CLEAN=true
	fi
	git -C "$CLAUDE_PROJECT_DIR" fetch origin "$DEFAULT_BRANCH" >$OUT 2>&1 && \
	git -C "$CLAUDE_PROJECT_DIR" update-ref "refs/heads/$DEFAULT_BRANCH" "refs/remotes/origin/$DEFAULT_BRANCH" >$OUT 2>&1 || {
		log "⚠ Could not update $DEFAULT_BRANCH"
	}
	# update-ref moves the ref but leaves the index + working tree stale.
	# Only --hard reset if the tree was clean before we touched anything.
	if [ "$WAS_CLEAN" = true ]; then
		git -C "$CLAUDE_PROJECT_DIR" reset --hard --quiet >$OUT 2>&1 && \
		log "✓ Updated $DEFAULT_BRANCH to latest" || \
		log "⚠ Could not reset $DEFAULT_BRANCH"
	else
		git -C "$CLAUDE_PROJECT_DIR" reset --quiet >$OUT 2>&1 || true
		log "⚠ Updated $DEFAULT_BRANCH ref but preserved local changes (index reset only)"
	fi
fi

# --- opportunistic cleanup: remove stale worktrees whose remote branch is gone ---
WORKTREES_DIR="$CLAUDE_PROJECT_DIR/.claude/worktrees"
if [ -d "$WORKTREES_DIR" ]; then
	for wt_dir in "$WORKTREES_DIR"/*/; do
		[ -d "$wt_dir" ] || continue
		wt_name=$(basename "$wt_dir")
		wt_branch="worktree-$wt_name"
		# Skip the one we just removed
		[ "$wt_name" = "$NAME" ] && continue
		has_upstream=$(git -C "$CLAUDE_PROJECT_DIR" for-each-ref --format='%(upstream)' "refs/heads/$wt_branch" 2>/dev/null)
		should_clean=false
		reason=""

		if [ -n "$has_upstream" ]; then
			# Pushed but remote branch is now gone. Verify a merged PR exists before
			# cleaning up (remote branches can be deleted without merging).
			if ! git -C "$CLAUDE_PROJECT_DIR" show-ref --verify --quiet "refs/remotes/origin/$wt_branch" 2>/dev/null; then
				merged_pr=$(project_gh pr list --head "$wt_branch" --state merged --json number --jq '.[0].number' 2>/dev/null || true)
				if [ -n "$merged_pr" ]; then
					should_clean=true
					reason="remote branch gone, PR #$merged_pr merged"
				else
					log "⏭ Keeping worktree: $wt_name (remote branch gone but no merged PR found)"
				fi
			fi
		else
			# Never pushed — check if older than 24h with no unique commits
			wt_created=$(git -C "$CLAUDE_PROJECT_DIR" reflog show --format='%ct' "$wt_branch" 2>/dev/null | tail -1)
			wt_created=${wt_created:-0}
			now=$(date +%s)
			age_hours=$(( (now - wt_created) / 3600 ))
			if [ "$age_hours" -ge 24 ]; then
				unique_commits=$(git -C "$CLAUDE_PROJECT_DIR" rev-list --count "$DEFAULT_BRANCH".."$wt_branch" 2>/dev/null || echo 0)
				if [ "$unique_commits" -eq 0 ]; then
					should_clean=true
					reason="no upstream, no unique commits, ${age_hours}h old"
				else
					log "⏭ Keeping stale worktree: $wt_name (${age_hours}h old but has $unique_commits unpushed commit(s))"
				fi
			fi
		fi

		if [ "$should_clean" = true ]; then
			log "✓ Cleaning stale worktree: $wt_name ($reason)"
			rm -rf "$wt_dir/.venv" "$wt_dir/node_modules"
			git -C "$CLAUDE_PROJECT_DIR" worktree remove --force "$wt_dir" >$OUT 2>&1 || {
				rm -rf "$wt_dir"
				git -C "$CLAUDE_PROJECT_DIR" worktree prune >$OUT 2>&1 || true
			}
			if git -C "$CLAUDE_PROJECT_DIR" show-ref --verify --quiet "refs/heads/$wt_branch" 2>/dev/null; then
				git -C "$CLAUDE_PROJECT_DIR" branch -D "$wt_branch" >$OUT 2>&1 || true
			fi
		fi
	done
fi

# --- clean up worktree's project config dir (only if worktree was removed) ---
if [ "$SAFE_TO_REMOVE" = true ]; then
	WT_PROJECT=""

	# Try 1: sanitized path (matching Claude's / -> -, . -> - convention)
	sanitize_path() { echo "$1" | sed 's|/|-|g; s|\.|-|g'; }
	SANITIZED_WT=$(sanitize_path "$WORKTREE_DIR")
	[ -d "$HOME/.claude/projects/$SANITIZED_WT" ] && WT_PROJECT="$HOME/.claude/projects/$SANITIZED_WT"

	# Try 2: transcript_path from the payload contains the project dir name
	if [ -z "$WT_PROJECT" ]; then
		TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')
		if [ -n "$TRANSCRIPT" ]; then
			PROJ_FROM_TRANSCRIPT=$(echo "$TRANSCRIPT" | sed 's|.*/.claude/projects/||; s|/.*||')
			[ -d "$HOME/.claude/projects/$PROJ_FROM_TRANSCRIPT" ] && WT_PROJECT="$HOME/.claude/projects/$PROJ_FROM_TRANSCRIPT"
		fi
	fi

	# Try 3: scan sessions-index.json for matching originalPath
	if [ -z "$WT_PROJECT" ]; then
		for proj_dir in "$HOME/.claude/projects"/*/; do
			[ -d "$proj_dir" ] || continue
			index="$proj_dir/sessions-index.json"
			[ -f "$index" ] || continue
			orig=$(jq -r '.originalPath // empty' "$index" 2>/dev/null)
			if [ "$orig" = "$WORKTREE_DIR" ]; then
				WT_PROJECT="$proj_dir"
				break
			fi
		done
	fi

	if [ -n "$WT_PROJECT" ] && [ -d "$WT_PROJECT" ]; then
		rm -rf "$WT_PROJECT"
		log "✓ Removed worktree project config: $(basename "$WT_PROJECT")"
	fi
fi

# --- project-level hook ---
PROJECT_HOOK="$CLAUDE_PROJECT_DIR/.hooks/worktree-remove.sh"
if [ -x "$PROJECT_HOOK" ]; then
	echo "$INPUT" | "$PROJECT_HOOK"
fi
