#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)

LOGFILE="/tmp/worktree-$(date '+%Y-%m-%d').log"

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

# --- remove the worktree ---
if [ -d "$WORKTREE_DIR" ]; then
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

# --- update main ---
DEFAULT_BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@') || true
if [ -z "$DEFAULT_BRANCH" ]; then
	if git -C "$CLAUDE_PROJECT_DIR" show-ref --verify --quiet refs/heads/main 2>/dev/null; then
		DEFAULT_BRANCH="main"
	elif git -C "$CLAUDE_PROJECT_DIR" show-ref --verify --quiet refs/heads/master 2>/dev/null; then
		DEFAULT_BRANCH="master"
	fi
fi

if [ -n "$DEFAULT_BRANCH" ]; then
	git -C "$CLAUDE_PROJECT_DIR" fetch origin "$DEFAULT_BRANCH" >$OUT 2>&1 && \
	git -C "$CLAUDE_PROJECT_DIR" update-ref "refs/heads/$DEFAULT_BRANCH" "refs/remotes/origin/$DEFAULT_BRANCH" >$OUT 2>&1 && \
	log "✓ Updated $DEFAULT_BRANCH to latest" || \
	log "⚠ Could not update $DEFAULT_BRANCH"
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
			# Pushed but remote branch is now gone (e.g., PR merged and branch deleted)
			if ! git -C "$CLAUDE_PROJECT_DIR" show-ref --verify --quiet "refs/remotes/origin/$wt_branch" 2>/dev/null; then
				should_clean=true
				reason="remote branch gone"
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

# --- project-level hook ---
PROJECT_HOOK="$CLAUDE_PROJECT_DIR/.hooks/worktree-remove.sh"
if [ -x "$PROJECT_HOOK" ]; then
	echo "$INPUT" | "$PROJECT_HOOK"
fi
