#!/usr/bin/env bash
# ABOUTME: Emits OSC 7 to the user's TTY so Ghostty's working-directory
# ABOUTME: tracking follows the agent. Wired to CwdChanged and per-turn events.
set -euo pipefail

NEW_CWD=$(jq -r '.new_cwd // empty')
[ -n "$NEW_CWD" ] || NEW_CWD="$PWD"

TTY="${CLAUDE_INVOKER_TTY:-/dev/tty}"
HOST=$(hostname -s 2>/dev/null || echo localhost)

printf '\033]7;file://%s%s\033\\' "$HOST" "$NEW_CWD" >"$TTY" 2>/dev/null || true
