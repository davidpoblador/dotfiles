#!/usr/bin/env bash
# ABOUTME: SessionEnd hook — when a Claude session in a git worktree ends,
# ABOUTME: fetch + fast-forward the parent repo's default branch.
#
# Why: `claude agents` / central-coordinator agent-mode worktrees are torn
# down without firing WorktreeRemove, so the existing update_default_branch
# step that lives in worktree-remove.sh never runs for them. SessionEnd
# fires reliably for those sessions, so we use it as the backup signal.
# Idempotent: doubling up with WorktreeRemove on the normal `claude -w`
# path is fine — a second `git fetch` is a no-op when already current.

set -euo pipefail

# shellcheck source=_common.sh
source "$(dirname "$0")/_common.sh"

INPUT=$(cat)

# Prefer the payload's cwd; fall back to CLAUDE_PROJECT_DIR. Either is fine —
# we just need a path inside the (possibly worktree) repo.
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
[ -n "$CWD" ] || CWD="${CLAUDE_PROJECT_DIR:-}"
[ -n "$CWD" ] && [ -d "$CWD" ] || exit 0

# Only act when we're inside a *worktree* (not the main checkout). A worktree
# has its per-worktree GIT_DIR distinct from the shared git_common_dir; in the
# main checkout those resolve to the same `.git`.
GIT_DIR=$(git -C "$CWD" rev-parse --git-dir 2>/dev/null) || exit 0
COMMON_DIR=$(git -C "$CWD" rev-parse --git-common-dir 2>/dev/null) || exit 0
GIT_DIR_ABS=$(cd "$CWD" && cd "$GIT_DIR" && pwd -P)
COMMON_DIR_ABS=$(cd "$CWD" && cd "$COMMON_DIR" && pwd -P)
[ "$GIT_DIR_ABS" != "$COMMON_DIR_ABS" ] || exit 0

# `git worktree list --porcelain` always lists the main worktree first.
REPO_ROOT=$(git -C "$CWD" worktree list --porcelain 2>/dev/null | head -1 | sed 's/^worktree //')
[ -n "$REPO_ROOT" ] && [ -d "$REPO_ROOT" ] || exit 0

setup_logging "[session-end]"

NAME=$(basename "$CWD")
log "--- SessionEnd in worktree: $NAME (repo: $REPO_ROOT) ---"
log_quiet "    payload: $(jq -c . <<< "$INPUT" 2>/dev/null || echo "$INPUT" | tr '\n' ' ')"

DEFAULT_BRANCH=$(detect_default_branch "$REPO_ROOT")
if [ -z "$DEFAULT_BRANCH" ]; then
	log "⚠ Could not determine default branch for $REPO_ROOT"
	exit 0
fi

update_default_branch "$REPO_ROOT" "$DEFAULT_BRANCH"
log "✓ Updated $DEFAULT_BRANCH in $REPO_ROOT"
