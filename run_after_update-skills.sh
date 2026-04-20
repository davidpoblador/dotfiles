#!/bin/bash
# Reconcile ~/.agents/.skill-lock.json → ~/.agents/skills/ and ~/.claude/skills/.
# Every lockfile entry ends up installed and wired to Claude Code. Idempotent.
# Also runs `bunx skills update` weekly to refresh skill content.

set -euo pipefail

LOCKFILE="$HOME/.agents/.skill-lock.json"
AGENTS_DIR="$HOME/.agents/skills"
CLAUDE_DIR="$HOME/.claude/skills"
STAMP="${XDG_CACHE_HOME:-$HOME/.cache}/skills_last_update"

if ! command -v bunx &>/dev/null; then
  echo "[skills] bunx not found. Install mise tools (mise install), then re-run chezmoi apply."
  exit 0
fi

if [[ ! -f "$LOCKFILE" ]]; then
  echo "[skills] No lockfile at $LOCKFILE; nothing to reconcile."
  exit 0
fi

mkdir -p "$CLAUDE_DIR"

# Collect (source, name) pairs for skills missing from disk or not wired to Claude,
# then group by source so each source repo is cloned at most once.
missing=$(
  jq -r '.skills | to_entries[] | "\(.value.source)\t\(.key)"' "$LOCKFILE" |
  while IFS=$'\t' read -r source name; do
    if [[ ! -d "$AGENTS_DIR/$name" ]] || [[ ! -e "$CLAUDE_DIR/$name" ]]; then
      printf '%s\t%s\n' "$source" "$name"
    fi
  done |
  awk -F'\t' '{a[$1]=a[$1] " " $2} END {for (s in a) printf "%s\t%s\n", s, a[s]}'
)

if [[ -n "$missing" ]]; then
  echo "[skills] Reconciling $(printf '%s\n' "$missing" | wc -l | tr -d ' ') source(s) with lockfile..."
  while IFS=$'\t' read -r source names; do
    # shellcheck disable=SC2086
    bunx skills add "$source" --skill $names --agent claude-code -g -y
  done <<<"$missing"
fi

# Weekly refresh of skill content.
if [[ ! -f "$STAMP" ]] || [[ -n $(find "$STAMP" -mtime +7 2>/dev/null) ]]; then
  echo "[skills] Running weekly skills update..."
  bunx skills update -g -y || echo "[skills] update had failures; continuing"
  mkdir -p "$(dirname "$STAMP")"
  touch "$STAMP"
fi
