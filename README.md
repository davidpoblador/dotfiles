# Dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/).

## Fresh machine setup

### Dev (macOS)

```bash
# 1. Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Bootstrap chezmoi (installs chezmoi, clones repo, applies dotfiles)
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply davidpoblador --prompt
```

Chezmoi prompts for email, full name, and profile. Hit Enter on profile to accept
the default (`dev`). Chezmoi will install Homebrew packages, mise tools (uv, bun,
go, etc.), and deploy configs.

After bootstrap, import existing shell history into atuin:

```bash
atuin import auto
```

If you want to be able to mosh into this Mac, allow `mosh-server` through the
firewall (one-time, requires sudo):

```bash
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /opt/homebrew/bin/mosh-server
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblock /opt/homebrew/bin/mosh-server
```

### Prod (Linux)

Prerequisite: zsh must be installed.

```bash
# 1. Install zsh
sudo apt-get install -y zsh

# 2. Bootstrap chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply davidpoblador --prompt
```

At the prompts:

- **Email address:** `david@poblador.com`
- **Full name:** `David Poblador i Garcia`
- **Profile:** `prod`

The first run will set zsh as the default shell via `chsh` and stop with a
message. Log out fully and reconnect (if using SSH multiplexing, close the
shared connection first: `ssh -O exit <host>`). Then run:

```bash
~/bin/chezmoi apply
```

(Use the full path — no config files are deployed yet, so `~/bin` isn't on
PATH. Subsequent runs can use `chezmoi update` since `.zprofile` adds it.)

This installs mise (via curl), deploys configs, installs mise tools (starship,
uv, atuin, delta, etc.), and installs the `alltuner` CLI from the private
`alltuner/infrastructure` repo (requires SSH access to GitHub from the host).

After bootstrap, import existing shell history into atuin:

```bash
atuin import auto
```

## Day-to-day usage

```bash
chezmoi update              # Pull latest dotfiles and apply
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
| `.claude/` | Claude Code settings and hooks |
| `.agents/` | Shared `AGENTS.md`/`CLAUDE.md` and the agent-skills wishlist, consumed by every agent via symlink |
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

#### Notes

| Package | Description |
|---|---|
| obsidian | Markdown-based knowledge base |

#### Mac App Store

| App | Description |
|---|---|
| DaisyDisk | Disk space analyzer |
| Obsidian Web Clipper | Safari extension to clip web pages into Obsidian |
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

#### Adding a new mise tool

```bash
mise registry <tool>    # see which backends are available
mise use -g <tool>      # install + add to global config
# then: chezmoi re-add ~/.config/mise/config.toml to track the change
```

Prefer backends in this order: **core** (built-in) > **aqua** / **ubi** (single binary download) > **asdf** (legacy plugin). Core/aqua/ubi install cleanly. `asdf:` plugins refresh their git repo on every `mise install`/`upgrade`, adding one line of noise per apply — fine for a tool you need, annoying for orphans.

If `mise registry` only lists an `asdf:` backend, you can still use it — or pin another backend explicitly in `config.toml` (e.g. `"aqua:owner/repo" = "latest"`).

Cleaning up an orphan/legacy plugin:

```bash
mise uninstall <tool>           # remove the installed binary
mise plugins uninstall <tool>   # remove the plugin's git repo
mise cache clear <tool>         # flush version cache
```

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

## Agent skills

[Agent skills](https://skills.sh) are reusable bundles of procedural knowledge
that coding agents load on demand. They're installed once into every agent on the
machine — Claude Code, Codex, Gemini CLI, GitHub Copilot, OpenCode — using the
`skills` CLI (run via `bunx`). One copy lives in `~/.agents/skills/<skill>` and
each agent's skill directory symlinks to it, so there's a single physical copy per
skill.

The curated set is declared in `~/.agents/skills.wishlist` (chezmoi-managed), which
is the **single source of truth**. Each line is a source repo plus the skills to
pull from it:

```
anthropics/skills --skill frontend-design
pbakaus/impeccable --skill impeccable --skill layout --skill shape
stripe/ai --skill stripe-best-practices --skill stripe-projects --skill upgrade-stripe
```

### Adding a skill

```bash
skills-add <source> [--skill <name> ...]
# e.g. skills-add anthropics/skills --skill mcp-builder
```

`skills-add` appends the entry to the wishlist (writing to the chezmoi source),
applies it, and installs the skill into every agent. Commit the wishlist afterwards
to persist it — `cmc` (`chezmoi cd`), then commit and push.

### Installing the whole set

```bash
skills-bootstrap        # (re)install everything in the wishlist; idempotent
```

You rarely run this by hand. A chezmoi `run_onchange` hook runs it automatically
whenever the wishlist changes and on a fresh machine, so a freshly-bootstrapped
machine ends up with exactly the declared set. Installed skills also refresh daily
in the background (`bunx skills update`, via `.zshrc`).

### Browsing and inspecting

```bash
bunx skills find <query>    # search the skills.sh registry
bunx skills ls              # list what's installed
```

Resolved sources and content hashes are tracked in `~/.agents/.skill-lock.json`.
That file is deliberately **not** chezmoi-managed — the wishlist is what reproduces
the set, the lock is just the CLI's bookkeeping.

## Profiles

Chezmoi uses a `profile` variable to switch between dev and prod configs:

| Profile | Shell | Starship | Mise tools |
|---|---|---|---|
| `dev` (default) | zsh + antidote + plugins | Catppuccin Macchiato, powerline | Full (bun, node, go, rust, etc.) |
| `prod` | bash + aliases | Red hostname, compact | Minimal (uv, gh, starship) |

The profile is set once during `chezmoi init` and persists in `~/.config/chezmoi/chezmoi.toml`.

## Platform support

- **macOS**: Full dev environment with Homebrew packages, App Store apps, casks, fonts
- **Linux**: Production config with bash, starship, mise (uv, gh)

## Wallpaper sync (macOS)

Keeps desktop wallpapers consistent across Macs via a Syncthing-backed
folder. Pairs each attached display with the file whose aspect ratio is
closest to the display's native aspect, using `--scale=fill` (preserve
aspect, cover screen, crop overflow).

### Setup

1. Share `~/sync/exchange/wallpapers/` across your Macs with Syncthing.
   Chezmoi creates it on apply and symlinks `~/Pictures/wallpapers` to it
   for easy Finder access.
2. Drop image files in `~/Pictures/wallpapers`. Any `.png`/`.jpg`/`.jpeg`/
   `.heic`/`.tiff` works. Empty folder = script noops.
3. On each Mac:

   ```bash
   ~/.local/bin/wallpaper-sync            # dry-run: shows plan
   ~/.local/bin/wallpaper-sync --apply    # actually set wallpapers
   ```

The script is idempotent — re-running it does nothing if every display is
already on the picked file.

### Suggested files to keep in the folder

The matcher only needs aspect-ratio coverage; resolutions just need to be
big enough to render sharply when scaled/cropped to the target display.

| Aspect | Covers | Suggested min resolution |
|---|---|---|
| 1.778 (16:9) | Every modern external 4K/5K/6K monitor, most TVs | 5120×2880 |
| ~1.54 | All notched MacBooks (14"/16" MBP, M2+ MBA) | 3456×2234 |
| 2.389 (21:9) | Ultrawides (optional) | 3440×1440 |
| 1.6 (16:10) | Pre-notch MBPs, M1 MBA (optional) | 2560×1600 |

Naming convention in this repo: `WIDTHxHEIGHT.ext` (e.g. `5120x2880.png`).
Not required — the script reads actual image dimensions via `sips` — but
makes the folder self-documenting.

### Requirements

- `bun` in `PATH`. Dependencies (`wallpaper`, `systeminformation`) are
  auto-installed to bun's global cache on first run (needs network once).
- macOS. Linux/Windows aren't targets.
