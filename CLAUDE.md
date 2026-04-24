# Dotfiles repo — Claude Code instructions

## This is a PUBLIC repository

**NEVER commit secrets, credentials, tokens, API keys, passwords, or private hostnames to this repo.**

Before every commit, verify that no file contains:
- API keys or tokens (e.g. `sk-`, `ghp_`, `gho_`, `AKIA`, `Bearer`)
- Passwords or passphrases
- Private IP addresses or internal hostnames
- SSH private keys
- `.env` file contents
- Cloud account IDs

If a file needs secrets, use chezmoi templates with `chezmoi data` or environment variables.

## Repo structure

- Root: chezmoi-managed dotfiles for macOS dev machines
- `prod/`: standalone dotfiles for production Linux hosts (not managed by chezmoi)

## Conventions

- One commit per logical change
- Commit messages: lowercase, imperative, concise
- Test changes locally before pushing (new terminal, `chezmoi apply`)

## Shell scripts run by chezmoi

macOS ships `/bin/bash` 3.2 and that's what chezmoi uses for `run_*.sh`
hooks unless a shebang points elsewhere. Anything newer than bash 3.2 will
break silently on `chezmoi apply`. Avoid (or guard) bash-4+ features:

- `declare -A` / associative arrays — use newline-delimited strings and
  substring match, or a tmp file
- `${var,,}` / `${var^^}` case conversion — use `tr`
- `mapfile` / `readarray` — use `while read` loops
- `&>` redirection is fine in bash 3.2; `|&` is not

Smoke-test hooks with `/bin/bash path/to/script.sh` before pushing, not
just with whatever `bash` is first on `$PATH` (typically Homebrew's bash 5+).
