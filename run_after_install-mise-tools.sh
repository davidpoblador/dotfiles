#!/bin/bash
# Ensure all mise-managed tools are installed.

if ! command -v mise &>/dev/null; then
  if [ -f "$HOME/.local/bin/mise" ]; then
    export PATH="$HOME/.local/bin:$PATH"
  else
    echo "[mise] mise not found. Install with: curl -fsSL https://mise.jdx.dev/install.sh | bash"
    exit 0
  fi
fi

mise install -y
mise upgrade -y
