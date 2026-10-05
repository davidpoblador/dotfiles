#!/usr/bin/env bash
# ABOUTME: Runs a repo's own .hooks/workspace-setup.sh once per linked worktree,
# ABOUTME: on SessionStart, SubagentStart, and PostToolUse(EnterWorktree).
set -uo pipefail

# shellcheck source=_common.sh
source "$(dirname "$0")/_common.sh"

INPUT=$(cat)
EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // empty')
# Every trigger reports the worktree as cwd: a `claude --worktree` start, an
# isolated subagent's own worktree, and the root EnterWorktree just switched to.
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
[ -n "$CWD" ] && cd "$CWD" 2>/dev/null || true

git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Act only inside a *linked* worktree, never the primary checkout: in a linked
# worktree the per-worktree git dir differs from the shared common dir.
GIT_DIR=$(git rev-parse --absolute-git-dir 2>/dev/null) || exit 0
COMMON_DIR=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
[ "$GIT_DIR" = "$COMMON_DIR" ] && exit 0

# The stamp lives in the per-worktree git dir, so it disappears with the
# worktree. It keeps resumes, compactions and every later subagent from
# re-running a setup that already succeeded.
STAMP="$GIT_DIR/claude-workspace-setup.done"
[ -f "$STAMP" ] && exit 0

# The project owns its setup; nothing to do if it doesn't ship one.
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
SETUP="$ROOT/.hooks/workspace-setup.sh"
[ -f "$SETUP" ] || exit 0

# ROOT_PATH is the main checkout (the worktree's common git dir lives there), so
# the project script can link .env and friends from it.
MAIN=$(dirname "$COMMON_DIR")

setup_logging "[setup]"
log "--- workspace setup ($EVENT): $ROOT ---"
cd "$ROOT" || exit 0
if ROOT_PATH="$MAIN" bash "$SETUP" >>"$LOGFILE" 2>&1; then
	touch "$STAMP"
	log "✓ workspace setup done"
else
	rc=$?
	log "✗ workspace setup failed (exit $rc)"
	# Tell both the user and Claude, so a missing dependency isn't debugged blind.
	MSG="workspace-setup.sh failed (exit $rc) in $ROOT; see $LOGFILE"
	jq -nc --arg ev "$EVENT" --arg msg "$MSG" \
		'{systemMessage: $msg, hookSpecificOutput: {hookEventName: $ev, additionalContext: $msg}}'
fi
exit 0
