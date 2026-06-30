#!/usr/bin/env bash
# ABOUTME: Emits OSC 7 to the user's TTY so the terminal (Ghostty) tracks the
# ABOUTME: agent's working directory. Wired to SessionStart, CwdChanged, and Stop.
set -euo pipefail

# CwdChanged carries new_cwd (the destination); SessionStart/Stop carry cwd (and
# fall through to $PWD). Stop re-asserts at each turn end, catching cwd changes
# like EnterWorktree that CwdChanged does not propagate to the terminal.
CWD=$(jq -r '.new_cwd // .cwd // empty')
[ -n "$CWD" ] || CWD="$PWD"
# Full hostname, not the short name: Ghostty drops OSC 7 whose host doesn't match
# its gethostname() ("OSC 7 host must be local"), and on macOS that is the full
# name (e.g. host.local) — the same value Ghostty's own shell integration sends.
HOST=$(hostname 2>/dev/null || echo localhost)

printf '\033]7;file://%s%s\033\\' "$HOST" "$CWD" >"${CLAUDE_INVOKER_TTY:-/dev/tty}" 2>/dev/null || true
