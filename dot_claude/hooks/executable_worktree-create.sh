#!/bin/bash
set -euo pipefail

INPUT=$(cat)
NAME=$(echo "$INPUT" | jq -r '.name')
WORKTREE_DIR="$CLAUDE_PROJECT_DIR/.claude/worktrees/$NAME"

# Run default git worktree creation
git -C "$CLAUDE_PROJECT_DIR" worktree add "$WORKTREE_DIR" -b "worktree-$NAME" 2>&1 >&2

# Run project-local hook if it exists and is executable
PROJECT_HOOK="$CLAUDE_PROJECT_DIR/.hooks/worktree-create.sh"
if [ -x "$PROJECT_HOOK" ]; then
	echo "$INPUT" | "$PROJECT_HOOK" >&2
fi

# Always print the path — Claude Code requires this on stdout
echo "$WORKTREE_DIR"
