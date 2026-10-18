#!/usr/bin/env bash
# ABOUTME: UserPromptSubmit hook — when the prompt is `:t`, splits the agent's
# ABOUTME: Rex block to the right at the agent's cwd and blocks the LLM turn.
set -euo pipefail

INPUT=$(cat)
PROMPT=$(jq -r '.prompt // empty' <<< "$INPUT")

# Fast no-op for everything except the magic prompt — UserPromptSubmit fires
# on every submit, so this path has to stay cheap.
case "$PROMPT" in
	:t) ;;
	*) exit 0 ;;
esac

# shellcheck source=_common.sh
source "$(dirname "$0")/_common.sh"
setup_logging "[split]"

CWD=$(jq -r '.cwd // empty' <<< "$INPUT")
log_quiet "trigger: prompt=:t cwd=$CWD"

if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
	log_quiet "  WARN: invalid cwd, aborting split"
	jq -nc '{decision: "block", reason: "split-pane: invalid cwd"}'
	exit 0
fi

# Rex sets these in the terminal it hands the agent. Without them there is no
# block to split, and bare `rex` would autostart a server instead of saying so.
if [ -z "${REX_SESSION:-}" ] || [ -z "${REX_BLOCK:-}" ]; then
	log_quiet "  WARN: not a Rex terminal (REX_SESSION/REX_BLOCK unset)"
	jq -nc '{decision: "block", reason: "split-pane: not a Rex terminal"}'
	exit 0
fi

# stdout is the hook's decision channel, so rex's creation report goes nowhere.
# -c sets the new shell's cwd outright, so this path needs no OSC 7 tracking.
rex split -s "$REX_SESSION" -b "$REX_BLOCK" -c "$CWD" >/dev/null 2>>"$LOGFILE" || {
	rc=$?
	log_quiet "  rex split failed (exit $rc)"
	jq -nc '{decision: "block", reason: "split-pane: failed (see log)"}'
	exit 0
}

jq -nc '{decision: "block", reason: "split-pane opened"}'
