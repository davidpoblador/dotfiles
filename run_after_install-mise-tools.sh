#!/bin/bash
# Install mise-managed tools weekly, or immediately on first run (e.g. fresh machine setup).

STAMP="${XDG_CACHE_HOME:-$HOME/.cache}/mise_tools_last_install"

if [[ -f "$STAMP" ]] && [[ -z $(find "$STAMP" -mtime +7 2>/dev/null) ]]; then
  exit 0
fi

if ! command -v mise &>/dev/null; then
  echo "[mise] mise not found. Install Homebrew packages first (brew bundle)."
  exit 0
fi

echo "[mise] Installing tools..."
mise install -y
touch "$STAMP"
