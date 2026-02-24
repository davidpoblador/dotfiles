#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
NAME=$(echo "$INPUT" | jq -r '.name')
WORKTREE_DIR="$CLAUDE_PROJECT_DIR/.claude/worktrees/$NAME"
BRANCH="worktree-$NAME"

log() { echo "$*" >/dev/tty 2>/dev/null || true; }

mkdir -p "$CLAUDE_PROJECT_DIR/.claude/worktrees"

if [ -d "$WORKTREE_DIR" ]; then
	log "✓ Resuming existing worktree: $NAME"
else
	git -C "$CLAUDE_PROJECT_DIR" worktree add "$WORKTREE_DIR" -b "$BRANCH" HEAD >/dev/null 2>&1 || {
		log "⚠ Failed to create worktree '$NAME' (branch '$BRANCH' may already exist)"
		log "  Try: git branch -d worktree-$NAME"
		echo "$WORKTREE_DIR"
		exit 1
	}
	log "✓ Created worktree: $NAME"

	# --- .env copy (only on creation) ---
	if [ -f "$CLAUDE_PROJECT_DIR/.env" ]; then
		cp "$CLAUDE_PROJECT_DIR/.env" "$WORKTREE_DIR/.env"
		log "✓ Copied .env"
	fi

	# --- deterministic DEV_PORT (only on creation) ---
	hash_port() {
		local hash
		hash=$(echo -n "$1" | md5sum 2>/dev/null || echo -n "$1" | md5 -q)
		hash=$(echo "$hash" | tr -d -c '0-9' | head -c 5)
		echo $(((hash % 4000) + 14000))
	}

	DEV_PORT=$(hash_port "$BRANCH")

	ENV_LOCAL="$WORKTREE_DIR/.env.local"
	if [ -f "$CLAUDE_PROJECT_DIR/.env.local" ]; then
		cp "$CLAUDE_PROJECT_DIR/.env.local" "$ENV_LOCAL"
		if grep -q '^DEV_PORT=' "$ENV_LOCAL"; then
			sed -i "s/^DEV_PORT=.*/DEV_PORT=$DEV_PORT/" "$ENV_LOCAL"
		else
			echo "DEV_PORT=$DEV_PORT" >>"$ENV_LOCAL"
		fi
	else
		echo "DEV_PORT=$DEV_PORT" >"$ENV_LOCAL"
	fi
	log "✓ DEV_PORT=$DEV_PORT set in .env.local"

	# --- prek (only on creation) ---
	if [ -f "$WORKTREE_DIR/.pre-commit-config.yaml" ]; then
		if command -v uv >/dev/null 2>&1; then
			log "✓ Installing prek hooks..."
			(cd "$WORKTREE_DIR" && uv tool run prek install) >/dev/null 2>&1 || {
				log "⚠ prek install failed, continuing anyway"
			}
			log "✓ prek hooks installed"
		else
			log "⚠ uv not found in PATH, skipping"
		fi
	fi
fi

# --- uv: sync + compileall (always) ---
if [ -f "$WORKTREE_DIR/uv.lock" ]; then
	if command -v uv >/dev/null 2>&1; then
		log "✓ uv syncing..."
		(cd "$WORKTREE_DIR" && uv sync --frozen --quiet) >/dev/tty 2>&1 || {
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
		(cd "$WORKTREE_DIR" && bun install --frozen-lockfile --silent) >/dev/null 2>&1 || {
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

# stdout = path only
echo "$WORKTREE_DIR"
