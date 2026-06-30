#!/usr/bin/env bash
# ABOUTME: SessionStart/SubagentStart hook — runs a repo's own .hooks/workspace-setup.sh
# ABOUTME: in a freshly created worktree, so each project owns its dependency setup.
set -uo pipefail

INPUT=$(cat)
SOURCE=$(printf '%s' "$INPUT" | jq -r '.source // "startup"')
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
[ -n "$CWD" ] && cd "$CWD" 2>/dev/null || true

# Run on a fresh start (a new worktree's first session) and on subagent spawns
# (SubagentStart carries no source, so it defaults through). A SessionStart
# resume/clear/compact continues an already-set-up tree, so skip those.
[ "$SOURCE" = "startup" ] || exit 0

git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Act only inside a *linked* worktree, never the primary checkout: in a linked
# worktree the per-worktree git dir differs from the shared common dir.
GIT_DIR=$(git rev-parse --absolute-git-dir 2>/dev/null) || exit 0
COMMON_DIR=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
[ "$GIT_DIR" = "$COMMON_DIR" ] && exit 0

# The project owns its setup; nothing to do if it doesn't ship one.
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
SETUP="$ROOT/.hooks/workspace-setup.sh"
[ -f "$SETUP" ] || exit 0

# ROOT_PATH is the main checkout (the worktree's common git dir lives there), so
# the project script can link .env and friends from it. Idempotency is the
# project script's responsibility — it runs on every fresh worktree start.
MAIN=$(dirname "$COMMON_DIR")

cd "$ROOT" || exit 0
ROOT_PATH="$MAIN" bash "$SETUP" 2>&1 | sed 's/^/[workspace-setup] /' || true
exit 0
