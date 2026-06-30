#!/usr/bin/env bash
# ABOUTME: SessionEnd hook — when a Claude session in a git worktree ends,
# ABOUTME: fast-forward the parent default branch and clean the worktree's state.
#
# Why: with native worktree creation (no WorktreeCreate hook) the harness tears
# worktrees down *before* SessionEnd fires and without firing WorktreeRemove, so
# by the time this runs the worktree directory is already gone. SessionEnd still
# fires reliably with the worktree's path in the payload, so it is the one place
# that can ff the parent default branch and clean the orphaned project dir for
# these worktrees. Everything is derived from the path string, not the (possibly
# deleted) directory. Idempotent: doubling up with WorktreeRemove is fine.

set -euo pipefail

# shellcheck source=_common.sh
source "$(dirname "$0")/_common.sh"

INPUT=$(cat)

# The worktree's path from the payload. It may already be deleted on disk, so
# nothing below may depend on the directory existing.
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
[ -n "$CWD" ] || CWD="${CLAUDE_PROJECT_DIR:-}"

# Act only for worktree sessions. Worktrees always live under
# <repo>/.claude/worktrees/<name>, so the parent repo is the prefix before it.
case "$CWD" in
	*/.claude/worktrees/*) ;;
	*) exit 0 ;;
esac
REPO_ROOT="${CWD%%/.claude/worktrees/*}"
NAME="${CWD#"$REPO_ROOT/.claude/worktrees/"}"
[ -n "$REPO_ROOT" ] && [ -d "$REPO_ROOT" ] || exit 0

setup_logging "[session-end]"

log "--- SessionEnd in worktree: $NAME (repo: $REPO_ROOT) ---"
log_quiet "    payload: $(jq -c . <<< "$INPUT" 2>/dev/null || echo "$INPUT" | tr '\n' ' ')"

DEFAULT_BRANCH=$(detect_default_branch "$REPO_ROOT")
if [ -z "$DEFAULT_BRANCH" ]; then
	log "⚠ Could not determine default branch for $REPO_ROOT"
	exit 0
fi

update_default_branch "$REPO_ROOT" "$DEFAULT_BRANCH"
log "✓ Updated $DEFAULT_BRANCH in $REPO_ROOT"

# Native removal deletes the worktree before this hook and never fires
# WorktreeRemove, so the worktree's ~/.claude/projects/ dir is orphaned. Clean it
# only once the worktree is actually gone — a kept worktree keeps its dir.
if [ ! -d "$CWD" ]; then
	WT_PROJECT="$HOME/.claude/projects/$(sanitize_path "$CWD")"
	if [ -d "$WT_PROJECT" ]; then
		rm -rf "$WT_PROJECT" && log "✓ Removed worktree project config: $(basename "$WT_PROJECT")"
	fi
fi

# Opportunistically sweep merged/stale sibling worktrees. Native teardowns skip
# WorktreeRemove, so without this their merged worktrees never get cleaned. Skip
# the worktree this session ran in, and require merge evidence before removing
# (defensive).
#
# This sweep is best-effort. Its many unguarded git calls can fail transiently
# when the harness mutates a worktree concurrently (e.g. a session resuming in
# the same instant), which under `set -e` would abort the hook with a non-zero
# exit *after* main is already updated — surfacing as a spurious "SessionEnd
# hook error". The `|| log` both neutralizes `set -e` for this call and records
# the failure instead of crashing the hook.
clean_stale_worktrees "$REPO_ROOT" "$DEFAULT_BRANCH" "$NAME" "yes" \
	|| log "⚠ Cleanup sweep failed (non-fatal); $DEFAULT_BRANCH already updated"
