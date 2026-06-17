#!/usr/bin/env bash
# ABOUTME: PreToolUse hook for agent-browser: injects a per-project session name and
# ABOUTME: clears a stale Chrome SingletonLock so a crashed session can't wedge later launches.
set -euo pipefail

INPUT=$(cat)

TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
[ "$TOOL" = "Bash" ] || exit 0

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[[ "$COMMAND" == *agent-browser* ]] || exit 0

# agent-browser must be installed
command -v agent-browser >/dev/null 2>&1 || exit 0

# Clear a stale Chrome SingletonLock so a crashed session doesn't wedge every later
# launch. All sessions share one profile (one Chrome per user-data-dir); remove the
# lock only when no live process still holds it, so we never disturb a running browser.
PROFILE="$HOME/.agent-browser/profile"
if [ -L "$PROFILE/SingletonLock" ] && ! pgrep -f "$PROFILE" >/dev/null 2>&1; then
  rm -f "$PROFILE"/Singleton{Lock,Cookie,Socket}
fi

# Already has a session name set — don't override
[[ "$COMMAND" == *AGENT_BROWSER_SESSION_NAME* ]] && exit 0
[[ "$COMMAND" == *--session-name* ]] && exit 0

# Resolve the main repo root (works from worktrees too)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
MAIN_GIT=$(git -C "$PROJECT_DIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
MAIN_ROOT=$(dirname "$MAIN_GIT")

# Slugify: take basename, replace non-alphanumeric with dashes
SESSION_NAME=$(basename "$MAIN_ROOT" | tr -cs '[:alnum:]-' '-' | sed 's/^-//;s/-$//')
[ -n "$SESSION_NAME" ] || exit 0

jq -n --arg cmd "AGENT_BROWSER_SESSION_NAME=$SESSION_NAME $COMMAND" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    updatedInput: { command: $cmd }
  }
}'
