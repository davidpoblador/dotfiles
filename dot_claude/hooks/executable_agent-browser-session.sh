#!/usr/bin/env bash
# ABOUTME: PreToolUse hook that injects AGENT_BROWSER_SESSION_NAME into agent-browser commands.
# ABOUTME: Derives session name from the main git repo root (not worktree) for per-project persistence.
set -euo pipefail

INPUT=$(cat)

TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
[ "$TOOL" = "Bash" ] || exit 0

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[[ "$COMMAND" == *agent-browser* ]] || exit 0

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
