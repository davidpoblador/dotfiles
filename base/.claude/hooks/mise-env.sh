#!/usr/bin/env bash
# ABOUTME: SessionStart hook: makes every Bash tool call evaluate `mise hook-env`
# ABOUTME: in its own cwd, so project-pinned tools and [env] follow the agent.
set -uo pipefail

# The Bash tool's PATH is frozen when its shell snapshot is taken, with global
# mise installs ahead of the shims, so a project pinning another version of a
# global tool would silently get the global one. Claude Code sources this env
# file before each Bash command; a literal eval line (not a one-off `mise env`
# dump) re-resolves per directory and unsets the previous project's vars, the
# way interactive shell activation does. Costs ~40ms per Bash call.
[ -n "${CLAUDE_ENV_FILE:-}" ] || exit 0
command -v mise >/dev/null 2>&1 || exit 0

# shellcheck disable=SC2016  # the expansion must happen at source time, not now
LINE='eval "$(mise hook-env -s bash 2>/dev/null)"'
grep -qxF "$LINE" "$CLAUDE_ENV_FILE" 2>/dev/null || printf '%s\n' "$LINE" >>"$CLAUDE_ENV_FILE"
exit 0
