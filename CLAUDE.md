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
