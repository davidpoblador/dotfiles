# Skip system compinit in /etc/zsh/zshrc (we run our own in .zshrc)
skip_global_compinit=1

# Ensure brew/user binaries are on PATH for non-interactive shells (e.g. mosh,
# scp, launchd agents). brew first so mise shims end up in front of it.
[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
[[ -d "$HOME/bin" ]] && export PATH="$HOME/bin:$PATH"
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"
[[ -d "$HOME/.local/share/mise/shims" ]] && export PATH="$HOME/.local/share/mise/shims:$PATH"

# Machine profile: macs are dev, Linux hosts are prod. Selects the mise config
# overlay (~/.config/mise/config.$MISE_ENV.toml) and the starship config.
case "$OSTYPE" in
  darwin*) export MISE_ENV=dev ;;
  *)       export MISE_ENV=prod ;;
esac

# Don't quarantine cask apps — avoids the "downloaded from internet" warning
export HOMEBREW_CASK_OPTS="--no-quarantine"

# fnox decrypts with the Syncthing-distributed age identity where present
[[ -f "$HOME/sync/secrets/keys.txt" ]] && export FNOX_AGE_KEY_FILE="$HOME/sync/secrets/keys.txt"

# expose: config lives in synced secrets (server hostname is private).
# The script falls back to ~/.config/expose.env when this is unset.
export EXPOSE_CONFIG="$HOME/sync/secrets/expose.env"
