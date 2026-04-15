#!/bin/bash
# Install mise-managed tools weekly, or immediately on first run (e.g. fresh machine setup).

STAMP="${XDG_CACHE_HOME:-$HOME/.cache}/mise_tools_last_install"

if [[ -f "$STAMP" ]] && [[ -z $(find "$STAMP" -mtime +7 2>/dev/null) ]]; then
  exit 0
fi

if ! command -v mise &>/dev/null; then
  if [ -f "$HOME/.local/bin/mise" ]; then
    export PATH="$HOME/.local/bin:$PATH"
  else
    echo "[mise] mise not found. Install with: curl -fsSL https://mise.jdx.dev/install.sh | bash"
    exit 0
  fi
fi

echo "[mise] Installing tools..."
mise install -y
touch "$STAMP"
