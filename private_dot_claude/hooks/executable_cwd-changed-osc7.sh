#!/usr/bin/env bash
# ABOUTME: Emits OSC 7 to the user's TTY so Ghostty's working-directory
# ABOUTME: tracking follows the agent. Wired to CwdChanged and per-turn events.
set -euo pipefail

# shellcheck source=_common.sh
source "$(dirname "$0")/_common.sh"

INPUT=$(cat)
EVENT=$(jq -r '.hook_event_name // "unknown"' <<< "$INPUT")
setup_logging "[osc7:$EVENT]"

NEW_CWD=$(jq -r '.new_cwd // empty' <<< "$INPUT")
[ -n "$NEW_CWD" ] || NEW_CWD="$PWD"

TTY="${CLAUDE_INVOKER_TTY:-/dev/tty}"
HOST=$(hostname -s 2>/dev/null || echo localhost)
PARENT_CMD=$(ps -o command= -p "$PPID" 2>/dev/null | tr -s ' ' | cut -c1-80)

log_quiet "pid=$$ ppid=$PPID tty=$TTY cwd=$NEW_CWD parent='$PARENT_CMD'"
log_quiet "  payload: $(jq -c . <<< "$INPUT" 2>/dev/null || echo "$INPUT" | tr '\n' ' ')"
log_quiet "  emit: file://$HOST$NEW_CWD"
if [ ! -d "$NEW_CWD" ] || [ "$NEW_CWD" = "/" ]; then
	log_quiet "  WARN: cwd missing or root — would-skip if a guard were enabled"
fi

printf '\033]7;file://%s%s\033\\' "$HOST" "$NEW_CWD" >"$TTY" 2>/dev/null || true
