# Dotfiles repo — Claude Code instructions

## This is a PUBLIC repository

**NEVER commit secrets, credentials, tokens, API keys, passwords, or private hostnames to this repo.**

A gitleaks pre-commit hook enforces this. `mise bootstrap` installs it via
`prek install`; run that once by hand in a fresh clone if you commit before
bootstrapping. Treat it as a backstop, not a substitute for checking. Before
every commit, verify that no file contains:
- API keys or tokens (e.g. `sk-`, `ghp_`, `gho_`, `AKIA`, `Bearer`)
- Passwords or passphrases
- Private IP addresses or internal hostnames
- SSH private keys
- `.env` file contents
- Cloud account IDs

If something needs a secret, store it with fnox (`fnox set -g NAME value` for
global, or a project `fnox.toml`): values are age-encrypted inline and safe to
commit. The global config `dev/.config/fnox/config.toml` is a tracked dotfile;
`fnox set -g` edits it through the `~/.config/fnox/config.toml` symlink, so
commit the result via PR. Never commit plaintext secrets, and never read or
copy `~/sync/secrets/keys.txt` (the age identity).

## Repo structure

- `base/`: dotfiles deployed to every machine (`[dotfiles]` in `mise.toml`, symlink-each)
- `dev/`: dotfiles deployed to dev machines only (`mise.dev.toml`, loaded when `MISE_ENV=dev`)
- `mise.toml` / `mise.dev.toml`: `mise bootstrap` config (packages, defaults, repos, services, dotfiles, tasks)

## Conventions

- One commit per logical change
- Commit messages: lowercase, imperative, concise
- Test changes locally before pushing (new terminal; `mise dotfiles apply` / `mise bootstrap --dry-run` for structural changes)
- `mise dotfiles apply` must run from `~/repos/dotfiles`, NEVER from a worktree: symlinks bake the config file's directory
- Keep `[dotfiles]` targets scoped to subtrees. A `symlink-each` entry scans its whole destination for stale links, so a `~` target walks every file under `$HOME` (~7M here: 4 minutes, silent). Scoped entries make the same apply take under a second. A whole-file entry scans nothing, which is why the root-level dotfiles are listed individually
- A worktree under `.claude/worktrees/` is nested inside the main checkout, so mise loads the parent's `mise.toml` too. Timing or config experiments run there also see the parent's entries; test outside the repo to isolate
- Any new script must be `chmod +x` before committing (symlink deployment preserves the git mode; systemd fails with 203/EXEC on 644)

## Shell scripts run by mise bootstrap

macOS ships `/bin/bash` 3.2 and that's what the `#!/bin/bash` shebang in
`[tasks.bootstrap]` and the `base/.local/bin` scripts resolves to. Anything
newer than bash 3.2 will break there. Avoid (or guard) bash-4+ features:

- `declare -A` / associative arrays — use newline-delimited strings and
  substring match, or a tmp file
- `${var,,}` / `${var^^}` case conversion — use `tr`
- `mapfile` / `readarray` — use `while read` loops
- `&>` redirection is fine in bash 3.2; `|&` is not

Smoke-test with `/bin/bash -n path/to/script.sh` before pushing, not just
with whatever `bash` is first on `$PATH` (typically Homebrew's bash 5+).
