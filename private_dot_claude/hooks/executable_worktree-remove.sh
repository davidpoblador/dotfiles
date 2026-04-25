#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=_common.sh
source "$(dirname "$0")/_common.sh"

INPUT=$(cat)

# WorktreeRemove payload has worktree_path (not name)
NAME=$(echo "$INPUT" | jq -r '.worktree_path // empty' | xargs basename 2>/dev/null || true)
if [ -z "$NAME" ]; then
	echo "[$(date '+%H:%M:%S')] [remove] ERROR: Could not extract worktree name" \
		>> "/tmp/worktree-hooks-$(date '+%Y-%m-%d').log"
	exit 0
fi

REPO_ROOT=$(resolve_repo_root "$CLAUDE_PROJECT_DIR")
WORKTREE_DIR="$REPO_ROOT/.claude/worktrees/$NAME"
BRANCH="worktree-$NAME"

setup_logging "[remove]"

echo "" >> "$LOGFILE"
log "--- WorktreeRemove: $NAME (branch: $BRANCH, repo: $REPO_ROOT) ---"
log_quiet "    payload: $(jq -c . <<< "$INPUT" 2>/dev/null || echo "$INPUT" | tr '\n' ' ')"

DEFAULT_BRANCH=$(detect_default_branch "$REPO_ROOT")

# --- guard: empty repo (no commits) — just clean up the directory ---
if ! git -C "$REPO_ROOT" rev-parse --verify HEAD >/dev/null 2>&1; then
	log "⚠ Repository has no commits, skipping branch checks"
	if [ -d "$WORKTREE_DIR" ]; then
		if is_dry_run; then
			log "[dry-run] would rm -rf $WORKTREE_DIR and run worktree prune"
		else
			rm -rf "$WORKTREE_DIR"
			git -C "$REPO_ROOT" worktree prune >"$OUT" 2>&1 || true
			log "✓ Removed worktree directory: $NAME"
		fi
	fi
	exit 0
fi

# In dry-run, the helpers below are already dry-run aware. The only thing
# left to guard is the project-config rm -rf and the project hook, which we
# short-circuit by exiting after the cleanup loop.
if is_dry_run; then
	log "[dry-run] would remove worktree $NAME (subject to merged-PR check)"
	log "[dry-run] skipping project-config rm and project hook"
	update_default_branch "$REPO_ROOT" "$DEFAULT_BRANCH"
	clean_stale_worktrees "$REPO_ROOT" "$DEFAULT_BRANCH" "$NAME" "yes"
	exit 0
fi

# --- check if the branch has unmerged work before removing ---
SAFE_TO_REMOVE=true

if git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$BRANCH" 2>/dev/null; then
	unique_commits=$(unique_commits_against "$REPO_ROOT" "$DEFAULT_BRANCH" "$BRANCH")
	if [ "$unique_commits" -gt 0 ]; then
		# Try git cherry first (portable, catches squash/rebase merges) then
		# fall back to a GitHub PR lookup for edge cases.
		if branch_is_squash_merged_into "$REPO_ROOT" "$DEFAULT_BRANCH" "$BRANCH"; then
			log "✓ Branch $BRANCH has $unique_commits local commit(s) but all are already in $DEFAULT_BRANCH (squash/rebase merged), safe to remove"
		elif merged_pr=$(merged_pr_for_branch "$REPO_ROOT" "$BRANCH") && [ -n "$merged_pr" ]; then
			log "✓ Branch $BRANCH has $unique_commits local commit(s) but PR #$merged_pr was merged, safe to remove"
		else
			SAFE_TO_REMOVE=false
			log "⚠ Branch $BRANCH has $unique_commits unmerged commit(s) and no merge evidence, preserving worktree"
		fi
	fi
fi

if [ "$SAFE_TO_REMOVE" = true ]; then
	if [ -d "$WORKTREE_DIR" ]; then
		remove_worktree_branch "$REPO_ROOT" "$WORKTREE_DIR" "$BRANCH"
		log "✓ Removed worktree: $NAME"
	else
		log "⚠ Worktree directory not found: $WORKTREE_DIR"
		git -C "$REPO_ROOT" worktree prune >"$OUT" 2>&1 || true
	fi
fi

# --- update main ---
if [ -n "$DEFAULT_BRANCH" ]; then
	update_default_branch "$REPO_ROOT" "$DEFAULT_BRANCH"
	log "✓ Updated $DEFAULT_BRANCH to latest"
fi

# --- opportunistic cleanup: remove stale worktrees whose remote branch is gone ---
clean_stale_worktrees "$REPO_ROOT" "$DEFAULT_BRANCH" "$NAME" "yes"

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
PROJECT_HOOK="$REPO_ROOT/.hooks/worktree-remove.sh"
if [ -x "$PROJECT_HOOK" ]; then
	echo "$INPUT" | "$PROJECT_HOOK"
fi
