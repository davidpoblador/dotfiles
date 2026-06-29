#!/usr/bin/env bash
set -euo pipefail

# Ignore the user's ~/.config/uv/uv.toml so options like `exclude-newer`
# don't get snapshotted into the worktree's uv.lock and show up as
# phantom drift vs. the version on the default branch.
export UV_NO_CONFIG=1

# shellcheck source=_common.sh
source "$(dirname "$0")/_common.sh"

INPUT=$(cat)
NAME=$(echo "$INPUT" | jq -r '.name')

REPO_ROOT=$(resolve_repo_root "$CLAUDE_PROJECT_DIR")
WORKTREE_DIR="$REPO_ROOT/.claude/worktrees/$NAME"
BRANCH="worktree-$NAME"

setup_logging "[create]"

echo "" >> "$LOGFILE"
log "--- WorktreeCreate: $NAME (branch: $BRANCH, repo: $REPO_ROOT) ---"
log_quiet "    payload: $(jq -c . <<< "$INPUT" 2>/dev/null || echo "$INPUT" | tr '\n' ' ')"

mkdir -p "$REPO_ROOT/.claude/worktrees"

# --- pick base ref: prefer origin's tip, fall back to local default branch ---
# Branching from origin/<default-branch> means the worktree always starts at
# the remote tip without touching the user's local default-branch ref or
# working tree. update_default_branch (heavier: update-ref + reset) is still
# used by the remove + session-end paths where refreshing local main IS the
# point.
DEFAULT_BRANCH=$(detect_default_branch "$REPO_ROOT")
if [ -n "$DEFAULT_BRANCH" ]; then
	if is_dry_run; then
		log "[dry-run] would fetch origin/$DEFAULT_BRANCH"
	else
		log "→ Fetching origin/$DEFAULT_BRANCH..."
		git -C "$REPO_ROOT" fetch origin "$DEFAULT_BRANCH" >"$OUT" 2>&1 \
			|| log "⚠ fetch failed, falling back to local $DEFAULT_BRANCH"
	fi
	if git -C "$REPO_ROOT" show-ref --verify --quiet "refs/remotes/origin/$DEFAULT_BRANCH" 2>/dev/null; then
		BASE_REF="origin/$DEFAULT_BRANCH"
	else
		BASE_REF="$DEFAULT_BRANCH"
	fi
	is_dry_run || log "✓ Base ref: $BASE_REF"
else
	BASE_REF="HEAD"
	log "⚠ Could not determine default branch, using HEAD"
fi

# --- empty repo / non-repo: auto-init + initial empty commit so worktrees work ---
# `claude -w` is an explicit opt-in to worktree mode; honor it on fresh
# repos/dirs instead of failing. For non-repo dirs, refuse to auto-init
# if there's pre-existing content (other than .claude/) — the user
# should run `git init` themselves so we don't quietly turn an arbitrary
# directory into a repo.
if ! git -C "$REPO_ROOT" rev-parse --verify HEAD >/dev/null 2>&1; then
	if ! git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
		extras=$(find "$REPO_ROOT" -mindepth 1 -maxdepth 1 ! -name .claude -print -quit 2>/dev/null)
		if [ -n "$extras" ]; then
			log "⚠ $REPO_ROOT is not a git repo and contains files; refusing to auto-init"
			log "  Run \`git init\` there yourself first if you want a worktree"
			echo "$REPO_ROOT is not a git repo and has existing files. Run 'git init' there first." >&2
			exit 2
		fi
		if is_dry_run; then
			log "[dry-run] would init git repo and create initial empty commit"
			echo "$WORKTREE_DIR"
			exit 0
		fi
		log "→ Initializing git repo in $REPO_ROOT..."
		git -C "$REPO_ROOT" init >"$OUT" 2>&1
	elif is_dry_run; then
		log "[dry-run] repo has no commits, would create initial empty commit"
		echo "$WORKTREE_DIR"
		exit 0
	fi
	log "→ Creating initial empty commit..."
	git -C "$REPO_ROOT" commit --allow-empty -m "Initial commit" >"$OUT" 2>&1
	log "✓ Initial empty commit created"
fi

# In dry-run, skip everything after the (dry-run-aware) default branch update
# except the cleanup loop — that is what dry-run exists to debug.
if is_dry_run; then
	log "[dry-run] would create worktree $WORKTREE_DIR on branch $BRANCH from $BASE_REF"
	log "[dry-run] skipping per-creation steps (submodules, .env, prek, uv, bun, project hook)"
	clean_stale_worktrees "$REPO_ROOT" "$BASE_REF" "$NAME" "no"
	echo "$WORKTREE_DIR"
	exit 0
fi

if [ -d "$WORKTREE_DIR" ]; then
	log "✓ Resuming existing worktree: $NAME"
else
	git -C "$REPO_ROOT" worktree add "$WORKTREE_DIR" -b "$BRANCH" "$BASE_REF" >"$OUT" 2>&1 || {
		log "⚠ Failed to create worktree '$NAME' (branch '$BRANCH' may already exist)"
		log "  Try: git branch -d worktree-$NAME"
		echo "$WORKTREE_DIR"
		exit 1
	}
	log "✓ Created worktree: $NAME"

	# --- git submodules (only on creation) ---
	if [ -f "$REPO_ROOT/.gitmodules" ]; then
		log "→ Initializing submodules..."
		# Resolve the real .git/modules dir (works for both main repos and worktrees)
		GIT_COMMON_DIR=$(git -C "$REPO_ROOT" rev-parse --git-common-dir 2>/dev/null)
		MODULES_DIR="$GIT_COMMON_DIR/modules"

		# Fast path: if modules are already cloned locally, point submodule URLs
		# at the local cache to avoid a remote fetch (~1s vs ~10s).
		if [ -d "$MODULES_DIR" ]; then
			git -C "$WORKTREE_DIR" submodule init >"$OUT" 2>&1 || true
			# $sm_path/$name/$toplevel are foreach's own variables, expanded by
			# the child shell git spawns — so the body must stay single-quoted.
			# shellcheck disable=SC2016
			git -C "$WORKTREE_DIR" submodule foreach --quiet \
				'mod=$(basename "$sm_path")
				 local_mod="'"$MODULES_DIR"'/$mod"
				 if [ -d "$local_mod" ]; then
				   git -C "$toplevel" config "submodule.$name.url" "file://$local_mod"
				 fi' >"$OUT" 2>&1 || true
			if git -C "$WORKTREE_DIR" -c protocol.file.allow=always submodule update --recursive --depth 1 >"$OUT" 2>&1; then
				log "✓ Submodules initialized (from local cache)"
			else
				log "⚠ Local cache init failed, falling back to remote..."
				git -C "$WORKTREE_DIR" submodule deinit --all --force >"$OUT" 2>&1 || true
				if git -C "$WORKTREE_DIR" submodule update --init --recursive --depth 1 >"$OUT" 2>&1; then
					log "✓ Submodules initialized (from remote)"
				else
					log "⚠ Submodule init failed, continuing anyway"
				fi
			fi
		else
			# No local module cache, clone from remote
			if git -C "$WORKTREE_DIR" submodule update --init --recursive --depth 1 >"$OUT" 2>&1; then
				log "✓ Submodules initialized"
			else
				log "⚠ Submodule init failed, continuing anyway"
			fi
		fi
	fi

	# --- .env symlink (only on creation) ---
	if [ -f "$REPO_ROOT/.env" ]; then
		ln -sf "$REPO_ROOT/.env" "$WORKTREE_DIR/.env"
		log "✓ Symlinked .env"
	fi
	if [ -f "$REPO_ROOT/.env.local" ]; then
		ln -sf "$REPO_ROOT/.env.local" "$WORKTREE_DIR/.env.local"
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
			log "→ Installing prek hooks..."
			if (cd "$WORKTREE_DIR" && uv tool run prek install) >"$OUT" 2>&1; then
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
		log "→ uv syncing..."
		# Array form so an empty flag list expands to nothing (rather than "")
		uv_flags=()
		[ "$OUT" = "/dev/null" ] && uv_flags=(--quiet)
		(cd "$WORKTREE_DIR" && uv sync --frozen "${uv_flags[@]}") >"$OUT" 2>&1 || {
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
		log "→ bun installing..."
		bun_flags=()
		[ "$OUT" = "/dev/null" ] && bun_flags=(--silent)
		(cd "$WORKTREE_DIR" && bun install --frozen-lockfile "${bun_flags[@]}") >"$OUT" 2>&1 || {
			log "⚠ bun install failed, continuing anyway"
		}
		log "✓ bun install done"
	else
		log "⚠ bun not found in PATH, skipping"
	fi
fi

# --- project-level hook (always) ---
PROJECT_HOOK="$REPO_ROOT/.hooks/worktree-create.sh"
if [ -x "$PROJECT_HOOK" ]; then
	log "→ Running project hook..."
	export WORKTREE_DIR
	echo "$INPUT" | "$PROJECT_HOOK" >"$OUT" 2>&1 || {
		log "⚠ Project hook failed, continuing anyway"
	}
	log "✓ Project hook done"
fi

# --- opportunistic cleanup: remove stale worktrees whose remote branch is gone ---
clean_stale_worktrees "$REPO_ROOT" "$BASE_REF" "$NAME" "no"

# --- clean up old log files (keep 7 days) ---
find /tmp -maxdepth 1 -name 'worktree-hooks-*.log' -mtime +7 -delete 2>/dev/null || true

# Tell Ghostty the worktree is the "cwd" so new panes open there.
# The trailing \e\\ is the OSC string terminator (ESC + backslash); the
# literal `\\` is two chars in the single-quoted format and printf decodes
# them to a single `\` — shellcheck SC1003 misreads it as quote-escaping.
#
# $TARGET_TTY (set by setup_logging) falls back to $CLAUDE_INVOKER_TTY
# when /dev/tty is unreachable, e.g. when this hook runs under a detached
# agent-team teammate that has no controlling terminal of its own.
ABS_WORKTREE_DIR=$(cd "$WORKTREE_DIR" && pwd -P)
# shellcheck disable=SC1003
printf '\e]7;file://%s%s\e\\' "$HOSTNAME" "$ABS_WORKTREE_DIR" >"$TARGET_TTY" 2>/dev/null || true

# stdout = path only
echo "$WORKTREE_DIR"
