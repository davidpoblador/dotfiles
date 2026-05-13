#!/usr/bin/env bash
# ABOUTME: CwdChanged hook that emits OSC 7 so Ghostty's working-directory
# ABOUTME: tracking follows the agent into worktrees and other cd moves.
set -euo pipefail

NEW_CWD=$(jq -r '.new_cwd // empty')
[ -n "$NEW_CWD" ] || exit 0

TTY="${CLAUDE_INVOKER_TTY:-/dev/tty}"
HOST=$(hostname -s 2>/dev/null || echo localhost)

printf '\033]7;file://%s%s\033\\' "$HOST" "$NEW_CWD" >"$TTY" 2>/dev/null || true
