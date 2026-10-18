#!/usr/bin/env bash
# ABOUTME: Emits OSC 7 to the user's TTY so Rex tracks the agent's working
# ABOUTME: directory. Wired to SessionStart, CwdChanged, and Stop.
set -euo pipefail

# CwdChanged carries new_cwd (the destination); SessionStart/Stop carry cwd (and
# fall through to $PWD). Stop re-asserts at each turn end, catching cwd changes
# like EnterWorktree that CwdChanged does not propagate to the terminal.
CWD=$(jq -r '.new_cwd // .cwd // empty')
[ -n "$CWD" ] || CWD="$PWD"
# The sequence carries a host field, so send the real one. Rex ignores it and keeps
# only the path (verified: a bogus host still moved the block's tracked pwd), but
# a terminal that does check wants the full name, which on macOS is host.local.
HOST=$(hostname 2>/dev/null || echo localhost)

# Written straight to the tty on purpose. A hook can also ask the harness to
# emit an escape sequence by returning `terminalSequence`, but that path only
# permits OSC 0/1/2/9/99/777 and BEL — OSC 7 is rejected by its allowlist. So
# this is the only channel that works; do not "modernise" it. stderr is
# silenced first so a session with no tty doesn't report the failed open.
printf '\033]7;file://%s%s\033\\' "$HOST" "$CWD" 2>/dev/null >"${CLAUDE_INVOKER_TTY:-/dev/tty}" || true
