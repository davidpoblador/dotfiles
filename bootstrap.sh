#!/bin/bash
# ABOUTME: One-command machine bootstrap: installs Homebrew (macs) and mise,
# ABOUTME: clones the repo, and converges. curl -fsSL <raw>/bootstrap.sh | bash

set -eu

REPO="$HOME/repos/dotfiles"

case "$(uname -s)" in
  Darwin) export MISE_ENV=dev ;;
  *)      export MISE_ENV=prod ;;
esac

command -v git >/dev/null 2>&1 || { echo "bootstrap: git is required" >&2; exit 1; }

if [ "$MISE_ENV" = dev ] && ! command -v brew >/dev/null 2>&1 && [ ! -x /opt/homebrew/bin/brew ]; then
  echo "bootstrap: installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"

if ! command -v mise >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/mise" ]; then
  echo "bootstrap: installing mise"
  curl -fsSL https://mise.jdx.dev/install.sh | bash
fi
export PATH="$HOME/.local/bin:$PATH"

if [ ! -d "$REPO/.git" ]; then
  mkdir -p "$HOME/repos"
  git clone https://github.com/davidpoblador/dotfiles "$REPO"
fi

cd "$REPO"
mise trust
mise bootstrap --yes

if [ "$MISE_ENV" = prod ]; then
  loginctl enable-linger 2>/dev/null || true
fi

echo "bootstrap: done — open a new shell"
