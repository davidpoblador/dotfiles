#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
NAME=$(echo "$INPUT" | jq -r '.name')
WORKTREE_DIR="$CLAUDE_PROJECT_DIR/.claude/worktrees/$NAME"
BRANCH="worktree-$NAME"

LOGFILE="/tmp/worktree.log"
log() { echo "[$(date '+%H:%M:%S')] [create] $*" | tee -a "$LOGFILE" >/dev/tty 2>/dev/null || true; }
if [ "${HOOK_DEBUG:-0}" = "1" ]; then
	OUT=/dev/tty
else
	OUT=/dev/null
fi
echo "" >> "$LOGFILE"
echo "=== WorktreeCreate $(date) ===" >> "$LOGFILE"
echo "NAME=$NAME WORKTREE_DIR=$WORKTREE_DIR BRANCH=$BRANCH" >> "$LOGFILE"
echo "CLAUDE_PROJECT_DIR=$CLAUDE_PROJECT_DIR" >> "$LOGFILE"

mkdir -p "$CLAUDE_PROJECT_DIR/.claude/worktrees"

# --- ensure main/master is up to date with remote ---
DEFAULT_BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@') || true
if [ -z "$DEFAULT_BRANCH" ]; then
	# fallback: check if main or master exists
	if git -C "$CLAUDE_PROJECT_DIR" show-ref --verify --quiet refs/heads/main 2>/dev/null; then
		DEFAULT_BRANCH="main"
	elif git -C "$CLAUDE_PROJECT_DIR" show-ref --verify --quiet refs/heads/master 2>/dev/null; then
		DEFAULT_BRANCH="master"
	fi
fi

if [ -n "$DEFAULT_BRANCH" ]; then
	log "✓ Fetching origin and updating $DEFAULT_BRANCH..."
	git -C "$CLAUDE_PROJECT_DIR" fetch origin "$DEFAULT_BRANCH" >$OUT 2>&1 || {
		log "⚠ fetch failed, continuing with local $DEFAULT_BRANCH"
	}
	git -C "$CLAUDE_PROJECT_DIR" update-ref "refs/heads/$DEFAULT_BRANCH" "refs/remotes/origin/$DEFAULT_BRANCH" 2>$OUT || {
		log "⚠ update-ref failed, continuing with local $DEFAULT_BRANCH"
	}
	BASE_REF="$DEFAULT_BRANCH"
	log "✓ $DEFAULT_BRANCH is up to date"
else
	BASE_REF="HEAD"
	log "⚠ Could not determine default branch, using HEAD"
fi

if [ -d "$WORKTREE_DIR" ]; then
	log "✓ Resuming existing worktree: $NAME"
else
	git -C "$CLAUDE_PROJECT_DIR" worktree add "$WORKTREE_DIR" -b "$BRANCH" "$BASE_REF" >$OUT 2>&1 || {
		log "⚠ Failed to create worktree '$NAME' (branch '$BRANCH' may already exist)"
		log "  Try: git branch -d worktree-$NAME"
		echo "$WORKTREE_DIR"
		exit 1
	}
	log "✓ Created worktree: $NAME"

	# --- git submodules (only on creation) ---
	if [ -f "$CLAUDE_PROJECT_DIR/.gitmodules" ]; then
		log "✓ Initializing submodules..."
		if git -C "$WORKTREE_DIR" submodule update --init --recursive --depth 1 >$OUT 2>&1; then
			log "✓ Submodules initialized"
		else
			log "⚠ Submodule init failed, continuing anyway"
		fi
	fi

	# --- .env symlink (only on creation) ---
	if [ -f "$CLAUDE_PROJECT_DIR/.env" ]; then
		ln -sf "$CLAUDE_PROJECT_DIR/.env" "$WORKTREE_DIR/.env"
		log "✓ Symlinked .env"
	fi
	if [ -f "$CLAUDE_PROJECT_DIR/.env.local" ]; then
		ln -sf "$CLAUDE_PROJECT_DIR/.env.local" "$WORKTREE_DIR/.env.local"
		log "✓ Symlinked .env.local"
	fi

	# --- prek (only on creation) ---
	if [ -f "$WORKTREE_DIR/.pre-commit-config.yaml" ]; then
		if command -v uv >/dev/null 2>&1; then
			# Remove core.hooksPath if set (leftover from old pre-commit)
			if git -C "$WORKTREE_DIR" config --get core.hooksPath >/dev/null 2>&1; then
				git -C "$WORKTREE_DIR" config --local --unset-all core.hooksPath 2>/dev/null || true
				log "✓ Cleared core.hooksPath (pre-commit leftover)"
			fi
			log "✓ Installing prek hooks..."
			if (cd "$WORKTREE_DIR" && uv tool run prek install) >$OUT 2>&1; then
				log "✓ prek hooks installed"
			else
				log "⚠ prek install failed, continuing anyway"
			fi
		else
			log "⚠ uv not found in PATH, skipping"
		fi
	fi
fi

# --- uv: sync + compileall (always) ---
if [ -f "$WORKTREE_DIR/uv.lock" ]; then
	if command -v uv >/dev/null 2>&1; then
		log "✓ uv syncing..."
		UV_QUIET=$( [ "$OUT" = "/dev/null" ] && echo "--quiet" || echo "" )
		(cd "$WORKTREE_DIR" && uv sync --frozen $UV_QUIET) >$OUT 2>&1 || {
			log "⚠ uv sync failed, continuing anyway"
		}
		log "✓ uv sync done"

		VENV_DIR="$WORKTREE_DIR/.venv"
		if [ -d "$VENV_DIR" ]; then
			nohup bash -c "cd '$WORKTREE_DIR' && uv run python -m compileall -q '$VENV_DIR/lib'" >/dev/null 2>&1 &
			log "✓ compileall detached to background"
		fi
	else
		log "⚠ uv not found in PATH, skipping"
	fi
fi

# --- bun: install (always) ---
if [ -f "$WORKTREE_DIR/bun.lock" ] || [ -f "$WORKTREE_DIR/bun.lockb" ]; then
	if command -v bun >/dev/null 2>&1; then
		log "✓ bun installing..."
		BUN_SILENT=$( [ "$OUT" = "/dev/null" ] && echo "--silent" || echo "" )
		(cd "$WORKTREE_DIR" && bun install --frozen-lockfile $BUN_SILENT) >$OUT 2>&1 || {
			log "⚠ bun install failed, continuing anyway"
		}
		log "✓ bun install done"
	else
		log "⚠ bun not found in PATH, skipping"
	fi
fi

# --- project-level hook (always) ---
PROJECT_HOOK="$CLAUDE_PROJECT_DIR/.hooks/worktree-create.sh"
if [ -x "$PROJECT_HOOK" ]; then
	log "✓ Running project hook..."
	echo "$INPUT" | "$PROJECT_HOOK" >/dev/null
	log "✓ Project hook done"
fi

# --- opportunistic cleanup: remove stale worktrees whose remote branch is gone ---
if [ -d "$CLAUDE_PROJECT_DIR/.claude/worktrees" ]; then
	git -C "$CLAUDE_PROJECT_DIR" fetch origin --prune >$OUT 2>&1 || true
	for stale_dir in "$CLAUDE_PROJECT_DIR/.claude/worktrees"/*/; do
		[ -d "$stale_dir" ] || continue
		stale_name=$(basename "$stale_dir")
		stale_branch="worktree-$stale_name"
		# Skip the current worktree
		[ "$stale_name" = "$NAME" ] && continue
		# Only stale if it was pushed (has upstream) but remote branch is now gone
		has_upstream=$(git -C "$CLAUDE_PROJECT_DIR" for-each-ref --format='%(upstream)' "refs/heads/$stale_branch" 2>/dev/null)
		[ -z "$has_upstream" ] && continue
		if ! git -C "$CLAUDE_PROJECT_DIR" show-ref --verify --quiet "refs/remotes/origin/$stale_branch" 2>/dev/null; then
			log "✓ Cleaning stale worktree: $stale_name (remote branch gone)"
			git -C "$CLAUDE_PROJECT_DIR" worktree remove --force "$stale_dir" >$OUT 2>&1 || {
				rm -rf "$stale_dir"
				git -C "$CLAUDE_PROJECT_DIR" worktree prune >$OUT 2>&1 || true
			}
			if git -C "$CLAUDE_PROJECT_DIR" show-ref --verify --quiet "refs/heads/$stale_branch" 2>/dev/null; then
				git -C "$CLAUDE_PROJECT_DIR" branch -D "$stale_branch" >$OUT 2>&1 || true
			fi
		fi
	done
fi

# Tell Ghostty the worktree is the "cwd" so new panes open there
ABS_WORKTREE_DIR=$(cd "$WORKTREE_DIR" && pwd -P)
printf '\e]7;file://%s%s\e\\' "$HOSTNAME" "$ABS_WORKTREE_DIR" >/dev/tty 2>/dev/null || true

# stdout = path only
echo "$WORKTREE_DIR"
