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

# Suppress no-op messages, show only actual changes
mise install -y 2>&1 | grep -vE "^mise all tools are installed$" || true
mise upgrade -y 2>&1 | grep -vE "^mise All tools are up to date$" || true

# Disable Go telemetry uploads (https://donottrack.sh/). Go has no env-var
# equivalent; the setting persists in ~/.config/go/telemetry/mode.
if command -v go &>/dev/null; then
  go telemetry off 2>/dev/null || true
fi
