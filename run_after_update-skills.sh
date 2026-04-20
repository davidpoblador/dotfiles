#!/bin/bash
# Reconcile ~/.agents/skills.list → installed skills for Claude Code. The manifest
# is the chezmoi-tracked source of truth (one "<source>\t<skill>" pair per line);
# the lockfile is ignored by chezmoi and lives on disk as runtime state.
#
# This hook is a consumer of the manifest and must never write to it: doing so
# would make chezmoi prompt about the file having changed on the next apply.
# Manifest regeneration is handled by the `skills-update` shell function.

set -euo pipefail

MANIFEST="$HOME/.agents/skills.list"
AGENTS_DIR="$HOME/.agents/skills"
CLAUDE_DIR="$HOME/.claude/skills"
STAMP="${XDG_CACHE_HOME:-$HOME/.cache}/skills_last_update"

if ! command -v bunx &>/dev/null; then
  echo "[skills] bunx not found. Install mise tools (mise install), then re-run chezmoi apply."
  exit 0
fi

if [[ ! -f "$MANIFEST" ]]; then
  echo "[skills] No manifest at $MANIFEST; nothing to reconcile."
  exit 0
fi

mkdir -p "$CLAUDE_DIR"

# Group missing/unwired skills by source repo so each source is cloned at most once.
missing=$(
  while IFS=$'\t' read -r source name; do
    [[ -z "$source" || "$source" == \#* ]] && continue
    # A skill counts as installed if Claude Code can see it — either as a
    # symlink into $AGENTS_DIR or as a real dir copied directly there (some
    # skills, e.g. pbakaus/impeccable's impeccable/layout/shape, install that
    # way and never populate $AGENTS_DIR).
    if [[ ! -e "$CLAUDE_DIR/$name" ]]; then
      printf '%s\t%s\n' "$source" "$name"
    fi
  done < "$MANIFEST" |
  awk -F'\t' '{a[$1]=a[$1] " " $2} END {for (s in a) printf "%s\t%s\n", s, a[s]}'
)

if [[ -n "$missing" ]]; then
  echo "[skills] Reconciling $(printf '%s\n' "$missing" | wc -l | tr -d ' ') source(s) from manifest..."
  while IFS=$'\t' read -r source names; do
    # </dev/null prevents bunx's TUI from consuming the here-string that feeds
    # this loop, which otherwise terminates iteration after the first source.
    # shellcheck disable=SC2086
    bunx skills add "$source" --skill $names --agent claude-code -g -y </dev/null ||
      echo "[skills] warning: bunx failed for $source ($names); continuing"
  done <<<"$missing"
fi

# Weekly refresh of skill content.
if [[ ! -f "$STAMP" ]] || [[ -n $(find "$STAMP" -mtime +7 2>/dev/null) ]]; then
  echo "[skills] Running weekly skills update..."
  bunx skills update -g -y || echo "[skills] update had failures; continuing"
  mkdir -p "$(dirname "$STAMP")"
  touch "$STAMP"
fi

