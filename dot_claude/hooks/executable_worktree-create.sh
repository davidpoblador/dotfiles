#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
NAME=$(echo "$INPUT" | jq -r '.name')
WORKTREE_DIR="$CLAUDE_PROJECT_DIR/.claude/worktrees/$NAME"
BRANCH="worktree-$NAME"

log() { echo "$*" >/dev/tty 2>/dev/null || true; }
if [ "${HOOK_DEBUG:-0}" = "1" ]; then
	OUT=/dev/tty
else
	OUT=/dev/null
fi

mkdir -p "$CLAUDE_PROJECT_DIR/.claude/worktrees"

if [ -d "$WORKTREE_DIR" ]; then
	log "✓ Resuming existing worktree: $NAME"
else
	git -C "$CLAUDE_PROJECT_DIR" worktree add "$WORKTREE_DIR" -b "$BRANCH" HEAD >$OUT 2>&1 || {
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

	# --- .env copy (only on creation) ---
	if [ -f "$CLAUDE_PROJECT_DIR/.env" ]; then
		cp "$CLAUDE_PROJECT_DIR/.env" "$WORKTREE_DIR/.env"
		log "✓ Copied .env"
	fi
	if [ -f "$CLAUDE_PROJECT_DIR/.env.local" ]; then
		cp "$CLAUDE_PROJECT_DIR/.env.local" "$WORKTREE_DIR/.env.local"
		log "✓ Copied .env.local"
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
		(cd "$WORKTREE_DIR" && uv sync --frozen --quiet) >$OUT 2>&1 || {
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
		(cd "$WORKTREE_DIR" && bun install --frozen-lockfile --silent) >$OUT 2>&1 || {
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

# Tell Ghostty the worktree is the "cwd" so new panes open there
ABS_WORKTREE_DIR=$(cd "$WORKTREE_DIR" && pwd -P)
printf '\e]7;file://%s%s\e\\' "$HOSTNAME" "$ABS_WORKTREE_DIR" >/dev/tty 2>/dev/null || true

# stdout = path only
echo "$WORKTREE_DIR"
