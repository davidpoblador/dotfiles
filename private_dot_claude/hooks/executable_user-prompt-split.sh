#!/usr/bin/env bash
# ABOUTME: UserPromptSubmit hook — when the prompt is `:t`, opens a Ghostty
# ABOUTME: split-right at the agent's cwd and blocks the LLM turn.
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

if ! "$(dirname "$0")/split-pane.sh" "$CWD" 2>>"$LOGFILE"; then
	log_quiet "  split-pane failed (exit $?)"
	jq -nc '{decision: "block", reason: "split-pane: failed (see log)"}'
	exit 0
fi

jq -nc '{decision: "block", reason: "split-pane opened"}'
