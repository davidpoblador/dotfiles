# Profiling: ZPROF=1 zsh -ic exit (zbench wraps this)
[[ -n "${ZPROF:-}" ]] && zmodload zsh/zprof

###########################################################
# Environment and Language Settings                       #
###########################################################

# Language settings
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export LC_CTYPE="en_US.UTF-8"

# Default editor
export EDITOR="vim"
export VISUAL="vim"

# Use XDG_CONFIG_HOME if set, otherwise default to ${HOME}/.config
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# fzf config file (theme, defaults)
[[ -f "${XDG_CONFIG_HOME}/fzf/config" ]] && export FZF_DEFAULT_OPTS_FILE="${XDG_CONFIG_HOME}/fzf/config"

# Mise-generated completions
fpath=(${XDG_DATA_HOME}/mise-completions/zsh $fpath)


###########################################################
# SDK Configuration                                       #
###########################################################

# Android SDK (macOS only)
if [[ -d "$HOME/Library/Android/sdk" ]]; then
  export ANDROID_HOME="$HOME/Library/Android/sdk"
  export PATH="$PATH:$ANDROID_HOME/emulator"
  export PATH="$PATH:$ANDROID_HOME/platform-tools"
fi


###########################################################
# Utility Functions                                       #
###########################################################

add_to_path() {
  if [[ ":$PATH:" != *":$1:"* ]]; then
    PATH="$1:${PATH}"
  fi
}

command_exists() {
  command -v "$1" &>/dev/null
}

# Cache a tool's shell-init output and source it, regenerating only when the
# binary is newer than the cache. Turns a per-shell subprocess spawn into a
# file source. Same pattern as the mise/starship caches below.
# Usage: cache_eval <cache-name> <binary> <init args...>
cache_eval() {
  local name=$1 bin=$2; shift 2
  local src; src=$(command -v "$bin" 2>/dev/null) || return
  ensure_dir_exists "${XDG_CACHE_HOME}/zsh"
  local cache="${XDG_CACHE_HOME}/zsh/${name}-init.zsh"
  [[ ! -s "$cache" || "$src" -nt "$cache" ]] && "$bin" "$@" > "$cache"
  source "$cache"
}

# Install a command's zsh completion as an autoloaded fpath function so its
# (often large) body loads lazily on first completion instead of being sourced
# into every shell. Regenerate when the binary changes, dropping the compdump
# so the next compinit re-registers it. Must run before compinit.
# Usage: ensure_completion <cmd> <binary> <generate args...>
ensure_completion() {
  local name=$1 bin=$2; shift 2
  local src; src=$(command -v "$bin" 2>/dev/null) || return
  local dir="${XDG_DATA_HOME}/zsh/completions"
  ensure_dir_exists "$dir"
  local comp="$dir/_$name"
  if [[ ! -s "$comp" || "$src" -nt "$comp" ]]; then
    "$bin" "$@" > "$comp"
    rm -f "${XDG_CACHE_HOME}/zsh/zcompdump"
  fi
}

ensure_dir_exists() {
  if [[ ! -d "$1" ]]; then
    mkdir -p "$1"
  fi
}

###########################################################
# Homebrew Setup                                          #
###########################################################
if command_exists brew; then
  # Re-run shellenv: /etc/zprofile's path_helper runs after .zshenv and
  # pushes /opt/homebrew/bin behind /usr/bin, making Apple's git win over
  # the Homebrew one (and breaking newer completions like `git chd<TAB>`).
  eval "$(brew shellenv)"

  FPATH="${HOMEBREW_PREFIX}/share/zsh/site-functions:${FPATH}"

  export HOMEBREW_NO_ANALYTICS=1
  export HOMEBREW_NO_ENV_HINTS=1
fi


###########################################################
# Telemetry Opt-outs                                      #
###########################################################
# https://donottrack.sh/ — universal flag plus per-tool overrides for CLIs
# that don't honor DO_NOT_TRACK. Kept in .zshrc (interactive shells only) so
# subshells spawned by `claude` don't inherit DO_NOT_TRACK=1 from a global
# default and opt claude out of telemetry against our wishes.
export DO_NOT_TRACK=1
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export SAM_CLI_TELEMETRY=0
export AZURE_CORE_COLLECT_TELEMETRY=0
export GATSBY_TELEMETRY_DISABLED=1
export STNOUPGRADE=1
export CLOUDSDK_CORE_DISABLE_USAGE_REPORTING=true


###########################################################
# History Configuration                                   #
###########################################################

HISTDIR="${XDG_DATA_HOME}/zsh"
HISTFILE="${HISTDIR}/history"

ensure_dir_exists "$HISTDIR"

# Zsh native history kept as fallback (atuin is the primary history tool)
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_IGNORE_SPACE
setopt APPEND_HISTORY

###########################################################
# Mise (version manager for dev tools)                    #
###########################################################

# Source cargo env first so mise activate can prepend shims over cargo/bin
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# Cache `mise activate zsh` output; regenerate when mise binary changes.
_mise_bin=$(command -v mise 2>/dev/null)
[[ -z "$_mise_bin" && -x "$HOME/.local/bin/mise" ]] && _mise_bin="$HOME/.local/bin/mise"
if [[ -n "$_mise_bin" ]]; then
  ensure_dir_exists "${XDG_CACHE_HOME}/zsh"
  _mise_cache="${XDG_CACHE_HOME}/zsh/mise-activate.zsh"
  [[ ! -s "$_mise_cache" || "$_mise_bin" -nt "$_mise_cache" ]] && \
    "$_mise_bin" activate zsh > "$_mise_cache"
  source "$_mise_cache"
fi
unset _mise_bin _mise_cache

# Authenticate GitHub API calls (mise, gh extension installs, etc.) to avoid
# the 60/hour unauthenticated rate limit. Runs after mise activate so that a
# mise-managed `gh` is already on PATH. No-ops if gh is missing or unauthed.
if command_exists gh && [[ -z "$GITHUB_TOKEN" ]]; then
  _gh_token="$(gh auth token 2>/dev/null)" || _gh_token=""
  [[ -n "$_gh_token" ]] && export GITHUB_TOKEN="$_gh_token"
  unset _gh_token
fi

###########################################################
# Plugins (antidote + zsh-defer, when available)          #
###########################################################

# Catppuccin syntax highlighting theme (must load before the plugin)
[[ -f "${XDG_CONFIG_HOME}/zsh/catppuccin-macchiato-syntax-highlighting.zsh" ]] && \
  source "${XDG_CONFIG_HOME}/zsh/catppuccin-macchiato-syntax-highlighting.zsh"

# Antidote plugin manager (cloned by mise bootstrap) — static-load pattern:
# avoid sourcing antidote.zsh on every startup; regenerate the bundle only
# when the manifest changes.
ANTIDOTE_DIR="${ZDOTDIR:-$HOME}/.antidote"
if [[ -d "$ANTIDOTE_DIR" ]]; then
  fpath=("$ANTIDOTE_DIR/functions" $fpath)
  autoload -Uz antidote

  _zsh_plugins="${ZDOTDIR:-$HOME}/.zsh_plugins"
  if [[ -z "$ANTIDOTE_HOME" ]]; then
    if [[ "$OSTYPE" == darwin* ]]; then
      ANTIDOTE_HOME="$HOME/Library/Caches/antidote"
    else
      ANTIDOTE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/antidote"
    fi
  fi
  zstyle ':antidote:static' zcompile yes
  if [[ ! ${_zsh_plugins}.zsh -nt ${_zsh_plugins}.txt ]] || [[ ! -d "$ANTIDOTE_HOME" ]]; then
    antidote bundle <"${_zsh_plugins}.txt" >| "${_zsh_plugins}.zsh"
    zcompile -R -- "${_zsh_plugins}.zsh.zwc" "${_zsh_plugins}.zsh"
  fi
  source "${_zsh_plugins}.zsh"
  unset _zsh_plugins

  # zsh-autosuggestions: use palette color 8 (mid-gray in both dark and light themes)
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
fi

###########################################################
# Tool Initialization                                     #
###########################################################

# Modern CLI replacements
if command_exists lsd; then
  alias ls="lsd"
  alias l="lsd -l"
else
  # Enable ls colors on Linux
  if [[ -x /usr/bin/dircolors ]]; then
    eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
  fi
  alias l='ls -la'
fi

if (( $+functions[zsh-defer] )); then
  zsh-defer -c 'cache_eval fzf fzf --zsh'
  zsh-defer -c 'cache_eval atuin atuin init zsh --disable-up-arrow'
  zsh-defer -c 'cache_eval zoxide zoxide init zsh'
  zsh-defer -c 'cache_eval fnox fnox activate zsh'
else
  cache_eval fzf fzf --zsh
  cache_eval atuin atuin init zsh --disable-up-arrow
  cache_eval zoxide zoxide init zsh
  cache_eval fnox fnox activate zsh
fi

# Print directory after zoxide jumps
export _ZO_ECHO=1

# Starship config per machine profile (dev on macs, prod on Linux; see .zshenv)
export STARSHIP_CONFIG="$HOME/.config/starship-${MISE_ENV:-dev}.toml"

# starship prompt (mise-managed; cache_eval re-inits when the shim changes)
cache_eval starship starship init zsh

# Broot - interactive directory tree navigator
if [[ -f "${XDG_CONFIG_HOME}/broot/launcher/bash/br" ]]; then
  source "${XDG_CONFIG_HOME}/broot/launcher/bash/br"
fi


# Keychain: persistent ssh-agent. Only needed in mosh sessions
# (SSH agent forwarding doesn't survive mosh's UDP handoff).
if [[ -n "$MOSH_CONNECTION" ]] && command_exists keychain && [[ -f "$HOME/.ssh/id_ed25519" ]]; then
  eval "$(keychain --eval --quiet --agents ssh id_ed25519)"
fi

###########################################################
# Key Bindings                                            #
###########################################################

# Ctrl-U: Delete from cursor to beginning of line
bindkey \^U backward-kill-line

# Word boundaries: these characters are part of a word for movement/deletion widgets
WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'

# Type a directory path to cd into it without typing "cd"
setopt AUTO_CD

# Disable `=cmd` path-substitution so a bare `===` token (common as a visual
# separator in `cmd; echo ===; other`) doesn't trigger `(eval):1: == not found`
setopt NO_EQUALS

###########################################################
# Final PATH Adjustments                                  #
###########################################################


# Remove duplicate PATH entries
typeset -U PATH

###########################################################
# Aliases & Custom Functions                              #
###########################################################

# Git shortcuts
alias ga='git add'
alias gc='git commit -m'
alias gps='git push'
alias gpl='git pull'
alias gs='git status'
alias gco='git checkout'
alias gb='git branch'

# Git workflows
gac() {
    git add .
    git commit -m "$1"
}

gnb() {
    git checkout main
    git pull
    git checkout -b "$1"
}

# Navigation
alias ..='cd ..'
alias ...='cd ../..'

# cd to the main working tree of the current git repo (useful from worktrees)
cdm() {
    local git_dir
    git_dir="$(git rev-parse --git-dir 2>/dev/null)" || { echo "Not in a git repo"; return 1; }
    [[ "$git_dir" == ".git" ]] && return 0
    cd "$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"
}

# Navigate to repos directory
rep() {
    if [ $# -eq 0 ]; then
        cd ~/repos
    else
        cd ~/repos/$1
    fi
}

# Modal AI platform
alias mr='modal run'
alias md='modal deploy'

# Python/UV package manager
alias uvpi='uv pip install'
alias uvpc='uv pip compile'
alias uvlu='uv lock --upgrade'
alias toad='uvx --from batrachian-toad toad'

# Development
alias c='code .'
alias zrc='vi ${HOME}/.zshrc'

# Claude Code
alias ccc='claude'
alias cccw='claude -w'
alias cccy='claude --dangerously-skip-permissions'
alias cccwy='claude --dangerously-skip-permissions -w'
alias agents='cd ~/repos && claude agents'

# Launch a background dig exploration in the digs workbench; topic inline
digs() {
    ( cd ~/repos/digs 2>/dev/null || { echo "digs: ~/repos/digs not found" >&2; exit 1; }
      claude --bg "$*" )
}

# GitHub
alias ghw='gh repo view --web'
alias ghp='gh pr list --web'
alias ghpr='gh pr view --web'

# System maintenance
# Formula-only: casks belong to mise bootstrap (see dotfiles-maintain)
command_exists brew && alias bubu='brew update && brew upgrade --formula --yes'
if command_exists apt; then
  alias apu='sudo apt update'
  alias apg='sudo apt upgrade'
fi

# Docker
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcr='docker compose restart'
alias dcl='docker compose logs -f --tail 100'

dlogs() { docker logs -f --tail 100 "$1"; }   # Follow container logs
dexec() { docker exec -it "$1" /bin/sh; }    # Shell into a container

# Dotfile management
alias dfc='cd ~/repos/dotfiles'
alias dfa='mise -C ~/repos/dotfiles dotfiles apply'
alias dfs='mise -C ~/repos/dotfiles dotfiles status'
alias dfu='git -C ~/repos/dotfiles pull && mise -C ~/repos/dotfiles dotfiles apply'
alias dfb='mise -C ~/repos/dotfiles bootstrap --yes'

# System (ss on Linux, lsof fallback on macOS)
if command_exists ss; then
  alias ports='ss -tlnp'
else
  alias ports='lsof -iTCP -sTCP:LISTEN -n -P'
fi

###########################################################
# Completion Setup                                        #
###########################################################

fpath+=~/.zfunc
if [[ -d "$HOME/.docker/completions" ]]; then
  fpath=("$HOME/.docker/completions" $fpath)
fi

# Tool completions installed as lazy-autoloaded fpath functions. uv ships a
# ~6800-line completion; autoloading defers that parse until first use instead
# of sourcing it into every shell. Generated before compinit so it registers.
fpath=("${XDG_DATA_HOME}/zsh/completions" $fpath)
ensure_completion uv uv generate-shell-completion zsh
ensure_completion uvx uvx --generate-shell-completion zsh

autoload -Uz compinit
ensure_dir_exists "${XDG_CACHE_HOME}/zsh"

# -C skips both the security audit and the dump-rebuild check, the cheapest
# path. Run a full compinit weekly (or when the dump is missing) to refresh
# the cache and catch fpath dirs that became world-writable. The (#q...) glob
# qualifier requires extendedglob, which is off by default in interactive shells.
() {
  setopt localoptions extendedglob
  local dump="${XDG_CACHE_HOME}/zsh/zcompdump"
  if [[ -s "$dump" && -z "$dump"(#qN.mh+168) ]]; then
    compinit -C -d "$dump"
  else
    compinit -d "$dump"
  fi
}

if [[ -s "${XDG_CACHE_HOME}/zsh/zcompdump" && (! -s "${XDG_CACHE_HOME}/zsh/zcompdump.zwc" || "${XDG_CACHE_HOME}/zsh/zcompdump" -nt "${XDG_CACHE_HOME}/zsh/zcompdump.zwc") ]]; then
  zcompile "${XDG_CACHE_HOME}/zsh/zcompdump"
fi

zstyle ':completion:*' menu select

# Show dotfiles in tab completion
setopt GLOB_DOTS

# Google Cloud SDK completions (SDK is mise-managed; gcloud itself via shims)
if command_exists gcloud; then
  GCP_SDK_PATH="$(mise where gcloud 2>/dev/null)"
  if [[ -n "$GCP_SDK_PATH" && -f "${GCP_SDK_PATH}/completion.zsh.inc" ]]; then
    if (( $+functions[zsh-defer] )); then
      zsh-defer source "${GCP_SDK_PATH}/completion.zsh.inc"
    else
      source "${GCP_SDK_PATH}/completion.zsh.inc"
    fi
  fi
fi

# Reset terminal modes that leak as visible chars when SSH drops mid-session:
# mouse tracking (1000/1002/1003/1006/1015), bracketed paste (2004),
# modifyOtherKeys, kitty extended keys (CSI <u), cursor visibility + shape,
# and SGR attributes. `stty sane` recovers cooked mode, echo, and signal keys.
# Symptom this cures: stray `0;120;45M` / `0;120;45m` from mouse events,
# bare `[>1u` / `[<u` from keyboard protocol, lingering paste markers.
reset-term() {
    printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l\e[?1015l\e[?2004l\e[>4;0m\e[<u\e[?25h\e[2 q\e[0m'
    stty sane 2>/dev/null
}

# Ghostty occasionally doesn't receive the keyboard-mode pop on `claude` exit.
# Also scrub DO_NOT_TRACK so claude itself isn't opted out via the interactive
# default above (subshells spawned by claude don't source .zshrc, so they're
# already clean).
#
# Capture this shell's tty path and pass it down as CLAUDE_INVOKER_TTY.
# Detached agent-team teammates spawned by claude have no controlling tty
# of their own, so hooks running under them can't write OSC sequences to
# /dev/tty (those writes silently no-op). The hooks fall back to
# $CLAUDE_INVOKER_TTY to reach the user's actual terminal — e.g. so
# WorktreeCreate can update Ghostty's OSC 7 cwd tracking.
if command_exists claude; then
  claude() {
      local tty_path
      if tty_path=$(tty 2>/dev/null); then
          env -u DO_NOT_TRACK CLAUDE_INVOKER_TTY="$tty_path" command claude "$@"
      else
          env -u DO_NOT_TRACK command claude "$@"
      fi
      local rc=$?
      reset-term
      return $rc
  }
fi

# Report slow interactive startup; zbench measures on demand
if [[ -n "${_shell_t0:-}" ]]; then
  _shell_ms=$(( (EPOCHREALTIME - _shell_t0) * 1000 ))
  (( _shell_ms > 500 )) && printf '[zsh] slow startup: %dms (run zbench for a breakdown)\n' $_shell_ms
  unset _shell_t0 _shell_ms
fi
zbench() {
  local i s
  for i in 1 2 3; do
    s=$EPOCHREALTIME
    zsh -ic exit
    printf '%dms\n' $(( (EPOCHREALTIME - s) * 1000 ))
  done
  echo "-- top offenders (zprof):"
  ZPROF=1 zsh -ic exit 2>/dev/null | head -14
}
[[ -n "${ZPROF:-}" ]] && zprof
