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

# Mirror the shell's MISE_ENV (macs are dev, Linux is prod; see .zshenv) so
# `mise install` resolves the same tool set the interactive shell will use.
case "$(uname -s)" in
  Darwin) export MISE_ENV=dev ;;
  *)      export MISE_ENV=prod ;;
esac

# Suppress no-op messages, show only actual changes
mise install -y 2>&1 | grep -vE "^mise all tools are installed$" || true
mise upgrade -y 2>&1 | grep -vE "^mise All tools are up to date$" || true

# Warn about tools installed but not pinned in config (e.g. left behind by
# `mise use -g`, which chezmoi overwrites on apply). Don't auto-remove: some
# may be wanted and belong in config/mise/config.toml instead.
if ! mise prune --tools --dry-run-code >/dev/null 2>&1; then
  echo "[mise] installed but not pinned in config:"
  mise ls --prunable
  echo "[mise] add wanted ones to mise/config.toml, drop the rest with: mise prune --tools"
fi

# Disable Go telemetry uploads (https://donottrack.sh/). Go has no env-var
# equivalent; the setting persists in ~/.config/go/telemetry/mode.
if command -v go &>/dev/null; then
  go telemetry off 2>/dev/null || true
fi
