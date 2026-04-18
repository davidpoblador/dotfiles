#!/bin/bash
# Install or update the alltuner CLI from the private infrastructure repo.
# Runs on every chezmoi apply to pick up latest main.

# Ensure uv is on PATH (mise shims)
if ! command -v uv &>/dev/null; then
  export PATH="${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims:$PATH"
fi

if ! command -v uv &>/dev/null; then
  echo "[alltuner] uv not found, skipping (run mise install first)"
  exit 0
fi

# Install or reinstall from the private repo via SSH
# --force reinstalls even if already present, so we pick up new commits
uv tool install --force --quiet git+ssh://git@github.com/alltuner/infrastructure.git 2>&1 || {
  echo "[alltuner] install failed — check SSH access to alltuner/infrastructure"
  exit 0
}
