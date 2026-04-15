#!/bin/bash
# Bootstrap production dotfiles. All user-space, no sudo required.
# Usage: curl -sS https://raw.githubusercontent.com/davidpoblador/dotfiles/main/prod/install.sh | bash
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/davidpoblador/dotfiles/main/prod"

echo "=== Production dotfiles setup ==="

###########################################################
# Install mise (user-space tool manager)                  #
###########################################################

if [ ! -f "$HOME/.local/bin/mise" ]; then
  echo "[mise] Installing..."
  curl -fsSL https://mise.jdx.dev/install.sh | bash
else
  echo "[mise] Already installed"
fi

export PATH="$HOME/.local/bin:$PATH"

###########################################################
# Deploy config files                                     #
###########################################################

mkdir -p "$HOME/.config"

# bashrc
if [ -f "$HOME/.bashrc" ] && ! grep -q "Production server .bashrc" "$HOME/.bashrc" 2>/dev/null; then
  cp "$HOME/.bashrc" "$HOME/.bashrc.bak"
  echo "[bashrc] Backed up existing to ~/.bashrc.bak"
fi
curl -fsSL "$REPO_RAW/bashrc" -o "$HOME/.bashrc"
echo "[bashrc] Deployed"

# starship config
mkdir -p "$HOME/.config"
curl -fsSL "$REPO_RAW/starship.toml" -o "$HOME/.config/starship.toml"
echo "[starship] Config deployed"

# mise config
mkdir -p "$HOME/.config/mise"
curl -fsSL "$REPO_RAW/mise.toml" -o "$HOME/.config/mise/config.toml"
echo "[mise] Config deployed"

###########################################################
# Install tools via mise                                  #
###########################################################

echo "[mise] Installing tools..."
"$HOME/.local/bin/mise" install -y

###########################################################
# Done                                                    #
###########################################################

echo ""
echo "=== Done ==="
echo "Open a new shell or run: source ~/.bashrc"
