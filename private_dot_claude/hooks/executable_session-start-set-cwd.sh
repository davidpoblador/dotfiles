#!/usr/bin/env bash
# ABOUTME: SessionStart hook — emit OSC 7 with the session's starting cwd
# ABOUTME: so Ghostty opens new panes there before any worktree is created.

set -euo pipefail

# shellcheck source=_common.sh
source "$(dirname "$0")/_common.sh"

INPUT=$(cat)

# Prefer the payload's cwd; fall back to CLAUDE_PROJECT_DIR. Either is fine —
# we just need a real directory to announce to Ghostty.
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
[ -n "$CWD" ] || CWD="${CLAUDE_PROJECT_DIR:-}"
[ -n "$CWD" ] && [ -d "$CWD" ] || exit 0

setup_logging "[session-start]"

ABS_CWD=$(cd "$CWD" && pwd -P)

# File-only — fires on every session start (including resumes/clears/compacts
# and every agent-team teammate), so keep it out of the user's tty.
log_quiet "--- SessionStart: $ABS_CWD ---"
log_quiet "    payload: $(jq -c . <<< "$INPUT" 2>/dev/null || echo "$INPUT" | tr '\n' ' ')"

# Tell Ghostty about the session's cwd so new panes open there even before
# the worktree-create hook runs. $TARGET_TTY (set by setup_logging) prefers
# $CLAUDE_INVOKER_TTY when set, so detached agent-team teammates still reach
# the user's actual terminal — same pattern as worktree-create.sh.
# shellcheck disable=SC1003
printf '\e]7;file://%s%s\e\\' "$HOSTNAME" "$ABS_CWD" >"$TARGET_TTY" 2>/dev/null || true
