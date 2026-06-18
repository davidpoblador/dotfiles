#!/bin/bash
# Install or update bun global CLIs. Runs on every chezmoi apply to pick up
# latest releases (subject to bunfig's minimumReleaseAge delay).

# Ensure bun on PATH (mise shims)
if ! command -v bun &>/dev/null; then
  export PATH="${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims:$PATH"
fi

if ! command -v bun &>/dev/null; then
  echo "[bun-globals] bun not found, skipping (run mise install first)"
  exit 0
fi

# --linker=hoisted so the bin symlink lands in the global bin folder; the
# global bunfig sets linker=isolated, which skips bin links for -g installs.
bun install -g --linker=hoisted @openai/codex 2>&1 || {
  echo "[bun-globals] codex install failed"
  exit 0
}
