#!/usr/bin/env bash
# ABOUTME: Emits OSC 7 to the user's TTY so the terminal (Ghostty) tracks the
# ABOUTME: agent's working directory. Wired to SessionStart and CwdChanged.
set -euo pipefail

# CwdChanged carries new_cwd (the destination); SessionStart carries cwd.
CWD=$(jq -r '.new_cwd // .cwd // empty')
[ -n "$CWD" ] || CWD="$PWD"
HOST=$(hostname -s 2>/dev/null || echo localhost)

printf '\033]7;file://%s%s\033\\' "$HOST" "$CWD" >"${CLAUDE_INVOKER_TTY:-/dev/tty}" 2>/dev/null || true
