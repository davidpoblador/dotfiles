#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
NAME=$(echo "$INPUT" | jq -r '.name')

# Resolve the main repo root (CLAUDE_PROJECT_DIR points to the worktree when
# Claude runs inside one, but we need the original repo for all operations)
REPO_ROOT=$(git -C "$CLAUDE_PROJECT_DIR" worktree list --porcelain 2>/dev/null | head -1 | sed 's/^worktree //')
if [ -z "$REPO_ROOT" ]; then
	REPO_ROOT="$CLAUDE_PROJECT_DIR"
fi

WORKTREE_DIR="$REPO_ROOT/.claude/worktrees/$NAME"
BRANCH="worktree-$NAME"

LOGFILE="/tmp/worktree-hooks-$(date '+%Y-%m-%d').log"
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [create] $*" | tee -a "$LOGFILE" >/dev/tty 2>/dev/null || true; }
if [ "${HOOK_DEBUG:-0}" = "1" ]; then
	OUT=/dev/tty
else
	OUT=/dev/null
fi

echo "" >> "$LOGFILE"
log "--- WorktreeCreate: $NAME (branch: $BRANCH) ---"
echo "  payload: $INPUT" >> "$LOGFILE"

mkdir -p "$REPO_ROOT/.claude/worktrees"

# --- ensure main/master is up to date with remote ---
DEFAULT_BRANCH=$(git -C "$REPO_ROOT" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@') || true
if [ -z "$DEFAULT_BRANCH" ]; then
	# fallback: check if main or master exists
	if git -C "$REPO_ROOT" show-ref --verify --quiet refs/heads/main 2>/dev/null; then
		DEFAULT_BRANCH="main"
	elif git -C "$REPO_ROOT" show-ref --verify --quiet refs/heads/master 2>/dev/null; then
		DEFAULT_BRANCH="master"
	fi
fi

if [ -n "$DEFAULT_BRANCH" ]; then
	log "✓ Fetching origin and updating $DEFAULT_BRANCH..."
	# Check if working tree is clean BEFORE moving the ref
	WAS_CLEAN=false
	if git -C "$REPO_ROOT" diff --quiet 2>/dev/null && \
	   git -C "$REPO_ROOT" diff --cached --quiet 2>/dev/null; then
		WAS_CLEAN=true
	fi
	git -C "$REPO_ROOT" fetch origin "$DEFAULT_BRANCH" >$OUT 2>&1 || {
		log "⚠ fetch failed, continuing with local $DEFAULT_BRANCH"
	}
	git -C "$REPO_ROOT" update-ref "refs/heads/$DEFAULT_BRANCH" "refs/remotes/origin/$DEFAULT_BRANCH" 2>$OUT || {
		log "⚠ update-ref failed, continuing with local $DEFAULT_BRANCH"
	}
	# update-ref moves the ref but leaves the index + working tree stale.
	# Only --hard reset if the tree was clean before we touched anything,
	# so we never discard real uncommitted work.
	if [ "$WAS_CLEAN" = true ]; then
		git -C "$REPO_ROOT" reset --hard --quiet >$OUT 2>&1 || true
	else
		git -C "$REPO_ROOT" reset --quiet >$OUT 2>&1 || true
		log "⚠ Working tree had local changes, preserved them (index reset only)"
	fi
	BASE_REF="$DEFAULT_BRANCH"
	log "✓ $DEFAULT_BRANCH is up to date"
else
	BASE_REF="HEAD"
	log "⚠ Could not determine default branch, using HEAD"
fi

# --- guard: empty repo (no commits) cannot support worktrees ---
if ! git -C "$REPO_ROOT" rev-parse --verify HEAD >/dev/null 2>&1; then
	log "⚠ Repository has no commits yet, cannot create worktree"
	log "  Make an initial commit first: git add <file> && git commit -m 'Initial commit'"
	echo "Repository has no commits yet. Make an initial commit before using worktree mode." >&2
	exit 2
fi

if [ -d "$WORKTREE_DIR" ]; then
	log "✓ Resuming existing worktree: $NAME"
else
	git -C "$REPO_ROOT" worktree add "$WORKTREE_DIR" -b "$BRANCH" "$BASE_REF" >$OUT 2>&1 || {
		log "⚠ Failed to create worktree '$NAME' (branch '$BRANCH' may already exist)"
		log "  Try: git branch -d worktree-$NAME"
		echo "$WORKTREE_DIR"
		exit 1
	}
	log "✓ Created worktree: $NAME"

	# --- git submodules (only on creation) ---
	if [ -f "$REPO_ROOT/.gitmodules" ]; then
		log "✓ Initializing submodules..."
		# Resolve the real .git/modules dir (works for both main repos and worktrees)
		GIT_COMMON_DIR=$(git -C "$REPO_ROOT" rev-parse --git-common-dir 2>/dev/null)
		MODULES_DIR="$GIT_COMMON_DIR/modules"

		# Fast path: if modules are already cloned locally, point submodule URLs
		# at the local cache to avoid a remote fetch (~1s vs ~10s).
		if [ -d "$MODULES_DIR" ]; then
			git -C "$WORKTREE_DIR" submodule init >$OUT 2>&1 || true
			git -C "$WORKTREE_DIR" submodule foreach --quiet \
				'mod=$(basename "$sm_path")
				 local_mod="'"$MODULES_DIR"'/$mod"
				 if [ -d "$local_mod" ]; then
				   git -C "$toplevel" config "submodule.$name.url" "file://$local_mod"
				 fi' >$OUT 2>&1 || true
			if git -C "$WORKTREE_DIR" -c protocol.file.allow=always submodule update --recursive --depth 1 >$OUT 2>&1; then
				log "✓ Submodules initialized (from local cache)"
			else
				log "⚠ Local cache init failed, falling back to remote..."
				git -C "$WORKTREE_DIR" submodule deinit --all --force >$OUT 2>&1 || true
				if git -C "$WORKTREE_DIR" submodule update --init --recursive --depth 1 >$OUT 2>&1; then
					log "✓ Submodules initialized (from remote)"
				else
					log "⚠ Submodule init failed, continuing anyway"
				fi
			fi
		else
			# No local module cache, clone from remote
			if git -C "$WORKTREE_DIR" submodule update --init --recursive --depth 1 >$OUT 2>&1; then
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
PROJECT_HOOK="$REPO_ROOT/.hooks/worktree-create.sh"
if [ -x "$PROJECT_HOOK" ]; then
	log "✓ Running project hook..."
	export WORKTREE_DIR
	echo "$INPUT" | "$PROJECT_HOOK" >$OUT 2>&1 || {
		log "⚠ Project hook failed, continuing anyway"
	}
	log "✓ Project hook done"
fi

# --- opportunistic cleanup: remove stale worktrees whose remote branch is gone ---
if [ -d "$REPO_ROOT/.claude/worktrees" ]; then
	git -C "$REPO_ROOT" fetch origin --prune >$OUT 2>&1 || true
	for stale_dir in "$REPO_ROOT/.claude/worktrees"/*/; do
		[ -d "$stale_dir" ] || continue
		stale_name=$(basename "$stale_dir")
		stale_branch="worktree-$stale_name"
		# Skip the current worktree
		[ "$stale_name" = "$NAME" ] && continue
		has_upstream=$(git -C "$REPO_ROOT" for-each-ref --format='%(upstream)' "refs/heads/$stale_branch" 2>/dev/null)
		should_clean=false
		reason=""

		if [ -n "$has_upstream" ]; then
			# Pushed but remote branch is now gone (e.g., PR merged and branch deleted)
			if ! git -C "$REPO_ROOT" show-ref --verify --quiet "refs/remotes/origin/$stale_branch" 2>/dev/null; then
				should_clean=true
				reason="remote branch gone"
			fi
		else
			# Never pushed — check if older than 24h with no unique commits.
			# %gd with --date=unix gives the reflog entry time (branch creation);
			# %ct would give the tip commit's timestamp, which is unrelated to age.
			wt_created=$(git -C "$REPO_ROOT" reflog show --date=unix --format='%gd' "$stale_branch" 2>/dev/null \
				| tail -1 | sed -E 's/.*@\{([0-9]+)\}/\1/')
			wt_created=${wt_created:-0}
			age_hours=$(( ($(date +%s) - wt_created) / 3600 ))
			if [ "$age_hours" -ge 24 ]; then
				unique_commits=$(git -C "$REPO_ROOT" rev-list --count "$BASE_REF".."$stale_branch" 2>/dev/null || echo 0)
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
			git -C "$REPO_ROOT" worktree remove --force "$stale_dir" >$OUT 2>&1 || {
				rm -rf "$stale_dir"
				git -C "$REPO_ROOT" worktree prune >$OUT 2>&1 || true
			}
			if git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$stale_branch" 2>/dev/null; then
				git -C "$REPO_ROOT" branch -D "$stale_branch" >$OUT 2>&1 || true
			fi
			# Guard: clear core.worktree if it pointed at the cleaned worktree
			configured_wt=$(git -C "$REPO_ROOT" config core.worktree 2>/dev/null || true)
			if [ "$configured_wt" = "$stale_dir" ] || [ "$configured_wt" = "${stale_dir%/}" ]; then
				git -C "$REPO_ROOT" config --unset core.worktree >$OUT 2>&1 || true
				log "✓ Cleared stale core.worktree for $stale_name"
			fi
		fi
	done
fi

# --- symlink auto-memory so all worktrees share the main repo's memory ---
# Claude sanitizes paths: / -> -, . -> - (so /foo/.claude -> -foo--claude)
sanitize_path() { echo "$1" | sed 's|/|-|g; s|\.|-|g'; }
SANITIZED_MAIN=$(sanitize_path "$REPO_ROOT")
SANITIZED_WT=$(sanitize_path "$WORKTREE_DIR")
MAIN_MEMORY="$HOME/.claude/projects/$SANITIZED_MAIN/memory"
WT_PROJECT="$HOME/.claude/projects/$SANITIZED_WT"
mkdir -p "$MAIN_MEMORY" "$WT_PROJECT"
ln -sfn "$MAIN_MEMORY" "$WT_PROJECT/memory"
log "✓ Symlinked auto-memory to main repo"

# --- clean up old log files (keep 7 days) ---
find /tmp -maxdepth 1 -name 'worktree-hooks-*.log' -mtime +7 -delete 2>/dev/null || true

# Tell Ghostty the worktree is the "cwd" so new panes open there
ABS_WORKTREE_DIR=$(cd "$WORKTREE_DIR" && pwd -P)
printf '\e]7;file://%s%s\e\\' "$HOSTNAME" "$ABS_WORKTREE_DIR" >/dev/tty 2>/dev/null || true

# stdout = path only
echo "$WORKTREE_DIR"
