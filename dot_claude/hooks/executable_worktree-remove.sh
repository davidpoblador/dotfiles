#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)

LOGFILE="/tmp/worktree.log"
echo "" >> "$LOGFILE"
echo "=== WorktreeRemove $(date) ===" >> "$LOGFILE"
echo "RAW_INPUT=$INPUT" >> "$LOGFILE"

# WorktreeRemove payload has worktree_path (not name)
NAME=$(echo "$INPUT" | jq -r '.worktree_path // empty' | xargs basename 2>/dev/null || true)
if [ -z "$NAME" ]; then
	echo "ERROR: Could not extract worktree name from input" >> "$LOGFILE"
	exit 0
fi

WORKTREE_DIR="$CLAUDE_PROJECT_DIR/.claude/worktrees/$NAME"
BRANCH="worktree-$NAME"

log() { echo "[$(date '+%H:%M:%S')] [remove] $*" | tee -a "$LOGFILE" >/dev/tty 2>/dev/null || true; }
if [ "${HOOK_DEBUG:-0}" = "1" ]; then
	OUT=/dev/tty
else
	OUT=/dev/null
fi
echo "NAME=$NAME WORKTREE_DIR=$WORKTREE_DIR BRANCH=$BRANCH" >> "$LOGFILE"
echo "CLAUDE_PROJECT_DIR=$CLAUDE_PROJECT_DIR" >> "$LOGFILE"

# --- remove the worktree ---
if [ -d "$WORKTREE_DIR" ]; then
	log "✓ Removing worktree: $NAME"
	git -C "$CLAUDE_PROJECT_DIR" worktree remove --force --force "$WORKTREE_DIR" >$OUT 2>&1 || {
		log "⚠ git worktree remove failed, cleaning up manually"
		rm -rf "$WORKTREE_DIR"
		git -C "$CLAUDE_PROJECT_DIR" worktree prune >$OUT 2>&1 || true
	}
	log "✓ Worktree removed"
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
		# Only stale if it was pushed (has upstream) but remote branch is now gone
		has_upstream=$(git -C "$CLAUDE_PROJECT_DIR" for-each-ref --format='%(upstream)' "refs/heads/$wt_branch" 2>/dev/null)
		[ -z "$has_upstream" ] && continue
		if ! git -C "$CLAUDE_PROJECT_DIR" show-ref --verify --quiet "refs/remotes/origin/$wt_branch" 2>/dev/null; then
			log "✓ Cleaning stale worktree: $wt_name (remote branch gone)"
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
