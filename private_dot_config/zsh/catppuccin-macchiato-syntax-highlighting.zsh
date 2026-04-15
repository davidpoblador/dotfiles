# Catppuccin Macchiato theme for zsh-syntax-highlighting
# Source this before zsh-syntax-highlighting loads.

ZSH_HIGHLIGHT_HIGHLIGHTERS=(main cursor)
typeset -gA ZSH_HIGHLIGHT_STYLES

# Commands and functions
ZSH_HIGHLIGHT_STYLES[alias]='fg=#a6da95'
ZSH_HIGHLIGHT_STYLES[suffix-alias]='fg=#a6da95'
ZSH_HIGHLIGHT_STYLES[global-alias]='fg=#a6da95'
ZSH_HIGHLIGHT_STYLES[function]='fg=#a6da95'
ZSH_HIGHLIGHT_STYLES[command]='fg=#a6da95'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=#a6da95,italic'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#a6da95'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#a6da95'
ZSH_HIGHLIGHT_STYLES[hashed-command]='fg=#a6da95'

# Options and arguments
ZSH_HIGHLIGHT_STYLES[autodirectory]='fg=#f5a97f,italic'
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#f5a97f'
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#f5a97f'

# Strings
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#eed49f'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument-unclosed]='fg=#ee99a0'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#eed49f'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument-unclosed]='fg=#ee99a0'
ZSH_HIGHLIGHT_STYLES[rc-quote]='fg=#eed49f'
ZSH_HIGHLIGHT_STYLES[command-substitution-quoted]='fg=#eed49f'
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter-quoted]='fg=#eed49f'

# Substitution and quoting
ZSH_HIGHLIGHT_STYLES[back-quoted-argument]='fg=#c6a0f6'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument-delimiter]='fg=#ed8796'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument-unclosed]='fg=#ee99a0'
ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]='fg=#ed8796'
ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]='fg=#ed8796'
ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=#c6a0f6'

# Variables
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=#cad3f5'
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument-unclosed]='fg=#ee99a0'
ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]='fg=#cad3f5'
ZSH_HIGHLIGHT_STYLES[assign]='fg=#cad3f5'
ZSH_HIGHLIGHT_STYLES[named-fd]='fg=#cad3f5'
ZSH_HIGHLIGHT_STYLES[numeric-fd]='fg=#cad3f5'

# Separators and redirections
ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#ed8796'
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]='fg=#cad3f5'
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter-unquoted]='fg=#cad3f5'
ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]='fg=#cad3f5'
ZSH_HIGHLIGHT_STYLES[redirection]='fg=#cad3f5'

# Paths and globbing
ZSH_HIGHLIGHT_STYLES[path]='fg=#cad3f5,underline'
ZSH_HIGHLIGHT_STYLES[path_pathseparator]='fg=#ed8796,underline'
ZSH_HIGHLIGHT_STYLES[path_prefix]='fg=#cad3f5,underline'
ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]='fg=#ed8796,underline'
ZSH_HIGHLIGHT_STYLES[globbing]='fg=#cad3f5'

# Defaults
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#ee99a0'
ZSH_HIGHLIGHT_STYLES[arg0]='fg=#cad3f5'
ZSH_HIGHLIGHT_STYLES[default]='fg=#cad3f5'
ZSH_HIGHLIGHT_STYLES[comment]='fg=#5b6078'
ZSH_HIGHLIGHT_STYLES[cursor]='fg=#cad3f5'
