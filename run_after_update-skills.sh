#!/bin/bash
# Reconcile ~/.agents/skills.list → installed skills for every agent in $AGENTS.
# The manifest is the chezmoi-tracked source of truth (one "<source>\t<skill>"
# pair per line); the lockfile is ignored by chezmoi and lives on disk as
# runtime state.
#
# This hook is a consumer of the manifest and must never write to it: doing so
# would make chezmoi prompt about the file having changed on the next apply.
# Manifest regeneration is handled by the `skills-update` shell function.

set -euo pipefail

# Agents to wire every skill into. bunx knows each agent's skill dir; content
# lives once under ~/.agents/skills and is symlinked into each agent's dir.
AGENTS=(claude-code codex gemini-cli github-copilot opencode openclaw)

MANIFEST="$HOME/.agents/skills.list"
AGENTS_DIR="$HOME/.agents/skills"
CLAUDE_DIR="$HOME/.claude/skills"
STAMP="${XDG_CACHE_HOME:-$HOME/.cache}/skills_last_update"
AGENTS_HASH_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/skills_agents_hash"

# Hash the agent list so a change (added/removed agent) busts the presence
# cache below and re-runs `bunx skills add` for every skill — otherwise
# skills already installed for one agent never get wired to newly-added ones.
agents_hash=$(printf '%s\n' "${AGENTS[@]}" | LC_ALL=C sort | shasum | awk '{print $1}')
prev_agents_hash=$(cat "$AGENTS_HASH_FILE" 2>/dev/null || true)
if [[ "$agents_hash" != "$prev_agents_hash" ]]; then
  echo "[skills] AGENTS list changed; re-wiring every skill."
  reconcile_all=1
else
  reconcile_all=0
fi

if ! command -v bunx &>/dev/null; then
  echo "[skills] bunx not found. Install mise tools (mise install), then re-run chezmoi apply."
  exit 0
fi

if [[ ! -f "$MANIFEST" ]]; then
  echo "[skills] No manifest at $MANIFEST; nothing to reconcile."
  exit 0
fi

mkdir -p "$CLAUDE_DIR"

# Build --agent args once: --agent a --agent b --agent c
agent_args=()
for a in "${AGENTS[@]}"; do
  agent_args+=(--agent "$a")
done

# Group missing/unwired skills by source repo so each source is cloned at most
# once. Presence is probed via the Claude Code dir as the canonical signal;
# the weekly refresh below re-reconciles every agent regardless.
missing=$(
  while IFS=$'\t' read -r source name; do
    [[ -z "$source" || "$source" == \#* ]] && continue
    # A skill counts as installed if Claude Code can see it — either as a
    # symlink into $AGENTS_DIR or as a real dir copied directly there (some
    # skills, e.g. pbakaus/impeccable's impeccable/layout/shape, install that
    # way and never populate $AGENTS_DIR).
    if (( reconcile_all )) || [[ ! -e "$CLAUDE_DIR/$name" ]]; then
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
    bunx skills add "$source" --skill $names "${agent_args[@]}" -g -y </dev/null ||
      echo "[skills] warning: bunx failed for $source ($names); continuing"
  done <<<"$missing"
fi

# Record the current AGENTS hash so the next apply skips the full re-wire
# unless someone edits the AGENTS list again.
mkdir -p "$(dirname "$AGENTS_HASH_FILE")"
printf '%s' "$agents_hash" > "$AGENTS_HASH_FILE"

# Evict skills that bunx tracks in its lockfile but that no longer appear in
# the manifest. Running `bunx skills remove` (rather than unlinking) also
# clears the shared content under ~/.agents/skills/<name> and every per-agent
# wiring, so orphans don't linger as "not linked" rows in `bunx skills ls`.
# Skills delivered outside bunx (e.g. notify-master via chezmoi) are absent
# from the lockfile and so stay immune.
LOCKFILE="$HOME/.agents/.skill-lock.json"
if [[ -f "$LOCKFILE" ]] && command -v jq &>/dev/null; then
  wanted=$'\n'
  while IFS=$'\t' read -r source name; do
    [[ -z "$source" || "$source" == \#* ]] && continue
    wanted+="$name"$'\n'
  done < "$MANIFEST"

  orphans=()
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    if [[ "$wanted" != *$'\n'"$name"$'\n'* ]]; then
      orphans+=("$name")
    fi
  done < <(jq -r '.skills | keys[]' "$LOCKFILE")

  if (( ${#orphans[@]} > 0 )); then
    echo "[skills] Evicting ${#orphans[@]} orphan(s): ${orphans[*]}"
    bunx skills remove -g -y "${orphans[@]}" </dev/null ||
      echo "[skills] warning: bunx remove failed; continuing"
  fi

  # Second pass: loose directories under ~/.agents/skills/ that bunx doesn't
  # track (leftovers from older versions of a skill pack that have since
  # dropped a skill). `bunx skills ls` still surfaces these as "not linked".
  if [[ -d "$AGENTS_DIR" ]]; then
    shopt -s nullglob
    for dir in "$AGENTS_DIR"/*; do
      [[ -d "$dir" ]] || continue
      name="$(basename "$dir")"
      [[ "$wanted" == *$'\n'"$name"$'\n'* ]] && continue
      if jq -e --arg n "$name" '.skills[$n]' "$LOCKFILE" >/dev/null 2>&1; then
        continue
      fi
      rm -rf "$dir"
      echo "[skills] removed loose orphan dir: $name"
    done
    shopt -u nullglob
  fi

  # Third pass: enforce AGENTS as the complete wiring set. `bunx skills add
  # --agent X` is additive — once wired, an agent sticks even after it leaves
  # AGENTS. Normalize bunx's display names (e.g. "Gemini CLI", "GitHub
  # Copilot") to identifiers by lowercasing + replacing spaces with dashes,
  # which matches bunx's accepted agent identifiers.
  allowed=$'\n'
  for a in "${AGENTS[@]}"; do
    allowed+="$a"$'\n'
  done
  extras=()
  while IFS= read -r agent; do
    [[ -z "$agent" ]] && continue
    [[ "$allowed" == *$'\n'"$agent"$'\n'* ]] && continue
    extras+=("$agent")
  done < <(
    bunx skills ls -g --json 2>/dev/null |
      jq -r '.[].agents[]' |
      tr '[:upper:]' '[:lower:]' |
      tr ' ' '-' |
      sort -u
  )
  if (( ${#extras[@]} > 0 )); then
    echo "[skills] Unwiring ${#extras[@]} extra agent(s): ${extras[*]}"
    for agent in "${extras[@]}"; do
      # bunx remove doesn't accept '*' or comma/space-joined skill lists; the
      # only working multi-skill form is repeated -s flags.
      skill_flags=()
      while IFS= read -r skill; do
        [[ -z "$skill" ]] && continue
        skill_flags+=(-s "$skill")
      done < <(
        bunx skills ls -g --json 2>/dev/null |
          jq -r --arg a "$agent" '
            .[] | select(.agents | map(ascii_downcase | gsub(" ";"-")) | index($a)) | .name
          '
      )
      if (( ${#skill_flags[@]} > 0 )); then
        bunx skills remove -g -y -a "$agent" "${skill_flags[@]}" </dev/null ||
          echo "[skills] warning: unwire failed for $agent; continuing"
      fi
    done
  fi
fi

# Weekly refresh of skill content.
if [[ ! -f "$STAMP" ]] || [[ -n $(find "$STAMP" -mtime +7 2>/dev/null) ]]; then
  echo "[skills] Running weekly skills update..."
  bunx skills update -g -y || echo "[skills] update had failures; continuing"
  mkdir -p "$(dirname "$STAMP")"
  touch "$STAMP"
fi
