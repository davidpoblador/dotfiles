#!/bin/bash
# Update agent skills weekly, or immediately on first run (e.g. fresh machine setup).

STAMP="${XDG_CACHE_HOME:-$HOME/.cache}/skills_last_update"

if [[ -f "$STAMP" ]] && [[ -z $(find "$STAMP" -mtime +7 2>/dev/null) ]]; then
  exit 0
fi

if ! command -v bunx &>/dev/null; then
  echo "[skills] bunx not found. Install mise tools (mise install), then run: bunx skills update -g -y"
  exit 0
fi

echo "[skills] Updating agent skills..."
bunx skills update -g -y
touch "$STAMP"
