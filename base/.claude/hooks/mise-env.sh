#!/usr/bin/env bash
# ABOUTME: SessionStart hook: makes every Bash tool call evaluate `mise env`
# ABOUTME: in its own cwd, so project-pinned tools and [env] follow the agent.
set -uo pipefail

# The Bash tool's PATH is frozen when its shell snapshot is taken, with global
# mise installs ahead of the shims, so a project pinning another version of a
# global tool would silently get the global one. Claude Code sources this env
# file before each Bash command; a literal eval line (not a one-off dump taken
# now) re-resolves per directory. Costs ~30ms per Bash call.
#
# `mise env`, not `mise hook-env`: hook-env also emits tool completion setup
# (bash `complete` or zsh `compdef`), which errors in the snapshot shell
# because the snapshot keeps the completion functions but not their state.
# Its export-only output is valid in both bash and zsh.
[ -n "${CLAUDE_ENV_FILE:-}" ] || exit 0
command -v mise >/dev/null 2>&1 || exit 0

# shellcheck disable=SC2016  # the expansion must happen at source time, not now
LINE='eval "$(mise env -s bash 2>/dev/null)"'
grep -qxF "$LINE" "$CLAUDE_ENV_FILE" 2>/dev/null || printf '%s\n' "$LINE" >>"$CLAUDE_ENV_FILE"
exit 0
