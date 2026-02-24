#!/bin/bash
set -euo pipefail

INPUT=$(cat)

# Run project-local hook if it exists and is executable
PROJECT_HOOK="$CLAUDE_PROJECT_DIR/.hooks/worktree-remove.sh"
if [ -x "$PROJECT_HOOK" ]; then
	echo "$INPUT" | "$PROJECT_HOOK"
fi
