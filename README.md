# Dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/).

## Fresh machine setup

```bash
# 1. Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Install chezmoi and apply dotfiles
brew install chezmoi
chezmoi init --apply davidpoblador

# 3. Install mise tools (bun, node, go, rust, etc.)
mise install

# 4. Install agent skills (requires bun from step 3)
bunx skills update -g -y
```

After step 2, `chezmoi apply` will:

- Install all Homebrew packages (via `run_onchange_darwin-install-packages.sh`)
- Attempt to update agent skills weekly (via `run_after_update-skills.sh`), or print
  instructions if `bunx` isn't available yet

## Day-to-day usage

```bash
chezmoi update              # Pull latest dotfiles and apply
skills-update               # Update agent skills and commit lock file to chezmoi
bubu                        # Update Homebrew packages
```

Mise tools auto-upgrade daily in the background via `.zshrc`.

## What's managed

| Path | What |
|---|---|
| `.zshrc`, `.zprofile`, `.zsh_plugins.txt` | Shell config, plugins (antidote + zsh-defer) |
| `.config/mise/config.toml` | Global dev tools: bun, node, go, rust, just, ruff, etc. |
| `.config/starship.toml` | Prompt |
| `.config/ghostty/`, `.config/tmux/` | Terminal |
| `.config/git/`, `.gitignore_global` | Git config |
| `.config/gh/` | GitHub CLI |
| `.config/bat/`, `.config/lazygit/` | CLI tools |
| `.claude/` | Claude Code settings, hooks, skills symlinks |
| `.agents/` | Agent skills (only lock file tracked, skills restored via `bunx`) |
| `.docker/` | Docker daemon config |
| `.ssh/` | SSH config (no keys) |
| `.vimrc` | Vim config |

## Agent skills

Skills are managed by `bunx skills`, not chezmoi. Only `.agents/.skill-lock.json` is tracked
as the source of truth (like `package-lock.json` vs `node_modules/`).

```bash
skills-update               # Update all skills + commit lock file to chezmoi
bunx skills update -g -y    # Update skills without committing to chezmoi
bunx skills ls -g            # List installed global skills
bunx skills add <repo> -g   # Add a new skill
```

Obsidian skills (installed via Git URL) need manual updates:

```bash
npx skills add git@github.com:kepano/obsidian-skills.git -g -y
```

## Platform support

- **macOS** (primary): Full support including App Store apps, casks, fonts
- **WSL/Linux**: Brew packages only (subset of macOS list)
