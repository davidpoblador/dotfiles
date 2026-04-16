# Dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/).

## Fresh machine setup

### Dev (macOS)

```bash
# 1. Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Bootstrap chezmoi (installs chezmoi, clones repo, applies dotfiles)
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply davidpoblador

# 3. Install mise tools (bun, node, go, rust, etc.)
mise install

# 4. Install agent skills (requires bun from step 3)
bunx skills update -g -y
```

Chezmoi will prompt for email and full name on first run. Profile defaults to `dev`.

After step 2, `chezmoi apply` will:

- Install all Homebrew packages (via `run_onchange_darwin-install-packages.sh`)
- Install mise tools weekly (via `run_after_install-mise-tools.sh`)
- Update agent skills weekly (via `run_after_update-skills.sh`)

### Prod (Linux)

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply davidpoblador --prompt
```

Chezmoi will prompt for email, full name, and profile. Enter `prod` for profile.
Requires zsh (`sudo apt-get install -y zsh`). Chezmoi will set it as default shell
and install mise, which installs starship, uv, gh, lsd, atuin, delta, and difftastic.

After bootstrap, import existing shell history into atuin:

```bash
atuin import auto
```

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

## Tools

### Homebrew packages

#### Terminal and shell

| Package | Description |
|---|---|
| antidote | Zsh plugin manager |
| chezmoi | Dotfile manager |
| mas | Mac App Store CLI |
| mise | Dev tool version manager |
| tmux | Terminal multiplexer |
| uv | Python package manager |
| zsh-completions | Additional zsh completions |
| zsh-syntax-highlighting | Syntax highlighting for zsh |

#### System tools

| Package | Description |
|---|---|
| curl | HTTP client |
| d2 | Declarative diagramming language |
| dive | Docker image layer explorer |
| duckdb | In-process SQL analytics engine |
| ffmpeg | Audio/video processing |
| fx | Terminal JSON viewer |
| imagemagick | Image manipulation |
| jless | Read-only JSON viewer with vim keybindings |
| jq | JSON processor |
| jnv | Interactive JSON filter with jq |
| knock | Port-knock client |
| lazydocker | Docker TUI |
| litecli | SQLite CLI with autocomplete |
| ngrok | Secure tunnels to localhost (cask) |
| qrencode | QR code generator |
| rsync | File sync |
| sc-im | Terminal spreadsheet editor |
| shfmt | Shell script formatter |
| silicon | Code screenshot generator |
| tokei | Code stats by language |
| tree | Directory listing |
| watchexec | File watcher / command runner |
| wget | HTTP client |
| yq | YAML processor |

#### Build dependencies

| Package | Description |
|---|---|
| cmake | Build system generator |
| coreutils | GNU core utilities |
| protobuf | Protocol Buffers compiler |
| sentencepiece | Text tokenizer |

#### AI

| Package | Description |
|---|---|
| agent-browser | Browser automation for AI agents |
| llm | CLI for LLMs |
| ollama | Local LLM runner |

#### Git

| Package | Description |
|---|---|
| gh | GitHub CLI |
| git | Version control |
| git-absorb | Auto-fixup staged changes into prior commits |
| git-delta | Syntax-highlighting pager for diffs |
| difftastic | Structural diff tool (`git difftool`) |
| git-lfs | Large file storage |
| lazygit | Git TUI |
| tig | Git text-mode interface |

#### Modern CLI replacements

| Package | Replaces | Description |
|---|---|---|
| bat | cat | Syntax-highlighted file viewer |
| bottom | top/htop | System monitor |
| broot | tree/find | Interactive directory navigator |
| cheat | man (examples) | Community-driven cheatsheets |
| curlie | curl | curl with httpie-style output |
| duff | diff (files) | Duplicate file finder |
| dust | du | Disk usage analyzer |
| fd | find | File finder |
| fzf | -- | Fuzzy finder |
| gping | ping | Ping with graph |
| httpie | curl | HTTP client with intuitive syntax |
| lsd | ls | File listing with icons and colors |
| procs | ps | Process viewer |
| ripgrep | grep | Fast text search |
| starship | -- | Cross-shell prompt |
| the_silver_searcher | grep | Fast code search (ag) |
| tlrc | man/tldr | Simplified man pages |
| zoxide | cd | Smarter directory jumping (z) |

#### Cloud and containers

| Package | Description |
|---|---|
| gcloud-cli | Google Cloud SDK (cask) |
| docker-desktop | Docker (cask) |
| docker-completion | Docker shell completions |

#### Fonts

| Package |
|---|
| font-jetbrains-mono-nerd-font |

#### Mac App Store

| App | Description |
|---|---|
| DaisyDisk | Disk space analyzer |
| Keynote | Presentations |
| Numbers | Spreadsheets |
| Pages | Documents |
| Slack | Team communication |
| Xcode | Apple development tools |

### Mise-managed dev tools

| Tool | Description |
|---|---|
| awscli | AWS CLI |
| bun | JavaScript runtime and package manager |
| gh | GitHub CLI |
| go | Go programming language |
| gopls | Go language server |
| just | Command runner (like make) |
| mc | MinIO client (S3-compatible) |
| mongosh | MongoDB shell |
| node | Node.js runtime |
| rust | Rust programming language |
| rust-analyzer | Rust language server |
| zig | Zig programming language |
| ruff | Python linter and formatter |
| ty | Python type checker |
| actionlint | GitHub Actions linter |
| atuin | Shell history search (SQLite-backed) |
| prek | Presentation tool |
| completions-sync | Auto-sync mise tool completions to zsh |

Mise also auto-installs dependencies on `cd`: runs `uv sync` when `uv.lock` exists without `.venv`, and `bun install` when `bun.lock` exists without `node_modules`.

### Zsh plugins

| Plugin | Description |
|---|---|
| romkatv/zsh-defer | Deferred loading for faster shell startup |
| Aloxaf/fzf-tab | Fuzzy completion using fzf in tab |
| zsh-users/zsh-autosuggestions | Fish-like autosuggestions from history |
| zsh-users/zsh-syntax-highlighting | Fish-like syntax highlighting |

All plugins except zsh-defer are lazy-loaded with `kind:defer`.

### Shell aliases

#### Git

| Alias | Command |
|---|---|
| `ga` | `git add` |
| `gc` | `git commit -m` |
| `gps` | `git push` |
| `gpl` | `git pull` |
| `gs` | `git status` |
| `gco` | `git checkout` |
| `gb` | `git branch` |

#### GitHub

| Alias | Command |
|---|---|
| `ghw` | `gh repo view --web` |
| `ghp` | `gh pr list --web` |
| `ghpr` | `gh pr view --web` |

#### Navigation

| Alias | Command |
|---|---|
| `..` | `cd ..` |
| `...` | `cd ../..` |

#### Python / uv

| Alias | Command |
|---|---|
| `uvpi` | `uv pip install` |
| `uvpc` | `uv pip compile` |
| `uvlu` | `uv lock --upgrade` |
| `toad` | `uvx --from batrachian-toad toad` |

#### Modal

| Alias | Command |
|---|---|
| `mr` | `modal run` |
| `md` | `modal deploy` |

#### Claude Code

| Alias | Command |
|---|---|
| `ccc` | `claude` |
| `cccw` | `claude -w` |
| `cccy` | `claude --dangerously-skip-permissions` |
| `cccwy` | `claude --dangerously-skip-permissions -w` |

#### Development

| Alias | Command |
|---|---|
| `c` | `code .` |
| `zrc` | `vi ~/.zshrc` |

#### Dotfiles

| Alias | Command |
|---|---|
| `cma` | `chezmoi add` |
| `cmc` | `chezmoi cd` |
| `bubu` | `brew update && brew upgrade` |

### Shell functions

| Function | Description |
|---|---|
| `gac <msg>` | `git add . && git commit -m <msg>` |
| `gnb <branch>` | Checkout main, pull, create new branch |
| `cdm` | cd to main worktree of current git repo |
| `rep [name]` | cd to `~/repos` or `~/repos/<name>` |
| `skills-update` | Update agent skills and commit lock file to chezmoi |

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

## Profiles

Chezmoi uses a `profile` variable to switch between dev and prod configs:

| Profile | Shell | Starship | Mise tools | Skills |
|---|---|---|---|---|
| `dev` (default) | zsh + antidote + plugins | Catppuccin Macchiato, powerline | Full (bun, node, go, rust, etc.) | Yes |
| `prod` | bash + aliases | Red hostname, compact | Minimal (uv, gh, starship) | No |

The profile is set once during `chezmoi init` and persists in `~/.config/chezmoi/chezmoi.toml`.

## Platform support

- **macOS**: Full dev environment with Homebrew packages, App Store apps, casks, fonts
- **Linux**: Production config with bash, starship, mise (uv, gh)
