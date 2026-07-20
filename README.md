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

Chezmoi prompts for email and full name. Chezmoi will install Homebrew
packages, mise tools (uv, bun, go, etc.), and deploy configs.

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
PATH. Subsequent runs can use `chezmoi update` since `.zshenv` adds it.)

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
| `.zshrc`, `.zsh_plugins.txt` | Shell config, plugins (antidote + zsh-defer) |
| `.config/mise/config.toml` | Global dev tools: bun, go, rust, just, ruff, etc. |
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

#### Shell and terminal

| Package | Description |
|---|---|
| chezmoi | Dotfile manager |
| mas | Mac App Store CLI |
| tmux | Terminal multiplexer |
| zsh-completions | Additional zsh completions |
| zsh-syntax-highlighting | Syntax highlighting for zsh |
| ghostty | Terminal emulator (cask) |

#### Everyday CLI utilities

| Package | Description |
|---|---|
| chafa | Render images as ANSI art |
| curl | HTTP client |
| d2 | Declarative diagramming language |
| duckdb | In-process SQL analytics engine |
| ffmpeg | Audio/video processing |
| fileicon | Set custom file and folder icons |
| fx | Terminal JSON viewer |
| imagemagick | Image manipulation |
| jless | Read-only JSON viewer with vim keybindings |
| jnv | Interactive jq |
| jq | JSON processor |
| knock | Port-knock client |
| litecli | SQLite CLI with autocomplete |
| mosh | Latency-tolerant SSH replacement |
| pv | Pipe progress meter |
| qrencode | QR code generator |
| rsync | File sync |
| sc-im | Terminal spreadsheet editor |
| shfmt | Shell script formatter |
| silicon | Code screenshot generator |
| telnet | Telnet client |
| tokei | Code stats by language |
| tree | Directory listing |
| watchexec | Run commands on file changes |
| watchman | File-watching service (RN / Xcode tooling) |
| wget | HTTP client |
| yq | YAML/XML/TOML processor |
| yt-dlp | Video downloader |

#### Modern Unix replacements

| Package | Replaces | Description |
|---|---|---|
| broot | tree/find | Interactive directory navigator |
| cheat | man (examples) | Community-driven cheatsheets |
| curlie | curl | curl with httpie-style output |
| duff | diff (files) | Duplicate file finder |
| gping | ping | Ping with graph |
| httpie | curl | HTTP client with intuitive syntax |
| procs | ps | Process viewer |
| the_silver_searcher | grep | Fast code search (ag) |
| tlrc | man/tldr | Simplified man pages |

#### Build toolchain

| Package | Description |
|---|---|
| cmake | Build system generator |
| coreutils | GNU core utilities |
| create-dmg | macOS DMG builder (release scripts) |
| protobuf | Protocol Buffers compiler |
| sentencepiece | Text tokenizer |

#### Git

| Package | Description |
|---|---|
| git | Version control (newer than macOS ships) |
| git-absorb | Auto-fixup staged changes into prior commits |
| tig | Git text-mode interface |

#### AI tooling

| Package | Description |
|---|---|
| gemini-cli | Google Gemini CLI |
| ant | CLI for the Claude Platform (cask) |
| copilot-cli | GitHub Copilot CLI (cask) |
| macwhisper | Local Whisper transcription (cask) |

#### Apps (casks)

| Package | Description |
|---|---|
| bitwarden | Password manager |
| docker-desktop | Docker Desktop (ships the docker CLI and shell completions) |
| obsidian | Markdown-based knowledge base |
| raycast | Launcher / Spotlight replacement |

#### Fonts

| Package |
|---|
| font-jetbrains-mono-nerd-font |

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

### Installed outside Homebrew and mise

Each of these has its own installer wired into a `run_` script or `.zshrc`.

| Tool | Install method | Description |
|---|---|---|
| mise | curl (`mise.jdx.dev`) | Dev tool version manager |
| antidote | git clone | Zsh plugin manager |
| claude | curl (`claude.ai/install.sh`) | Claude Code CLI |
| gcloud-cli | curl tarball | Google Cloud SDK |
| alltuner | uv tool (private repo) | Internal CLI from `alltuner/infrastructure` |
| codex | bun install -g (`@openai/codex`) | OpenAI Codex CLI |

### Mise-managed dev tools

Installed on all profiles:

| Tool | Description |
|---|---|
| ast-grep | Structural code search and rewrite |
| atuin | Shell history search (SQLite-backed) |
| bat | cat replacement with syntax highlighting |
| bottom | top/htop replacement |
| bun | JavaScript runtime and package manager |
| delta | Syntax-highlighting diff pager |
| difftastic | Structural diff tool (`git difftool`) |
| dive | Docker image layer explorer |
| dust | du replacement |
| fd | find replacement |
| frp | Fast reverse proxy |
| fzf | Fuzzy finder |
| gh | GitHub CLI |
| git-lfs | Large file storage |
| glow | Markdown renderer |
| go | Go programming language |
| hugo | Static site generator |
| just | Command runner (like make) |
| lazydocker | Docker TUI |
| lazygit | Git TUI |
| lsd | ls replacement with icons |
| restic | Backup tool |
| ripgrep | grep replacement |
| shellcheck | Shell script linter |
| starship | Cross-shell prompt |
| uv | Python package manager |
| zoxide | cd replacement (z) |

Dev profile only:

| Tool | Description |
|---|---|
| actionlint | GitHub Actions linter |
| awscli | AWS CLI |
| cf | Cloudflare CLI |
| gopls | Go language server |
| mise-completions-sync | Auto-sync mise tool completions to zsh |
| mongosh | MongoDB shell |
| prek | Git hook manager (pre-commit alternative) |
| ruff | Python linter and formatter |
| rust | Rust programming language |
| rust-analyzer | Rust language server |
| ty | Python type checker |
| zig | Zig programming language |

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
| `bubu` | `brew update && brew upgrade --yes` |

### Shell functions

| Function | Description |
|---|---|
| `gac <msg>` | `git add . && git commit -m <msg>` |
| `gnb <branch>` | Checkout main, pull, create new branch |
| `cdm` | cd to main worktree of current git repo |
| `rep [name]` | cd to `~/repos` or `~/repos/<name>` |

## Agent skills

[Agent skills](https://skills.sh) are reusable bundles of procedural knowledge
that coding agents load on demand. They're installed globally into every agent on
the machine — Claude Code, Codex, Gemini CLI, GitHub Copilot, OpenCode — with the
`skills` CLI (run via `bunx`). One canonical copy lives at `~/.agents/skills/<skill>`
and each agent's skills directory (e.g. `~/.claude/skills/<skill>`) is a symlink to
it, so there's a single physical copy per skill.

### The wishlist is the source of truth

The curated set is declared in `~/.agents/skills.wishlist`, a chezmoi-managed
plain-text file (source: `dot_agents/skills.wishlist`). It is the **only** thing
that reproduces the skill set on a new machine. Each non-blank, non-`#` line is a
source repo followed by the skills to pull from it:

```
anthropics/skills --skill frontend-design
pbakaus/impeccable --skill impeccable
shadcn/ui --skill shadcn
stripe/ai --skill stripe-best-practices --skill stripe-projects --skill upgrade-stripe
```

Nothing installs automatically. The wishlist is just intent; skills land on the
machine only when you run `skills-bootstrap` (below).

### Install (or reinstall) everything

```bash
skills-bootstrap
```

`skills-bootstrap` (`~/.local/bin`) reads the wishlist and runs `bunx skills add …
-g` for each line, installing into every agent. It's idempotent — re-running just
refreshes existing skills — so it's also how you apply wishlist changes and how a
fresh machine gets the full set.

### Add a skill

```bash
skills-add <source> --skill <name> [--skill <name> ...]
# e.g. skills-add anthropics/skills --skill skill-creator
```

`skills-add` (`~/.local/bin`) does the whole round trip: it installs the skill
into every agent, merges the entry into the wishlist source (located via
`chezmoi source-path`), applies it to the live copy, and commits + pushes the
change with `chezmoi git`. It pushes **directly to the default branch** — no PR,
by design for this curated file. The source may be a bare `owner/repo` slug or a
full GitHub URL, and re-adding a skill that's already listed is a no-op.

To add a skill by hand instead: `chezmoi cd`, edit `dot_agents/skills.wishlist`,
then `chezmoi apply ~/.agents/skills.wishlist` and `skills-bootstrap`.

### Remove a skill

Delete its line (or `--skill` token) from the wishlist source (`chezmoi cd`, edit
`dot_agents/skills.wishlist`), then `chezmoi apply ~/.agents/skills.wishlist`.
That stops future re-installs but does **not** uninstall what's already there —
remove that explicitly:

```bash
bunx skills remove <skill> -g
```

### Update skills

```bash
bunx skills update -g
```

Pulls the latest version of every installed skill. If a skill has been deleted
upstream, the update warns and offers to remove the now-orphaned local copy — say
yes, and drop the corresponding entry from the wishlist so bootstrap stops
requesting it.

### Browse and inspect

```bash
bunx skills find <query>    # search the skills.sh registry
bunx skills ls -g           # list installed global skills and their agents
```

### Runtime state vs. source of truth

The installed skills under `~/.agents/skills/` and the
`~/.agents/.skill-lock.json` lockfile are bunx's runtime state, deliberately
**not** chezmoi-managed (`.chezmoiignore` guards against re-adding them). The
wishlist is the reproducible source; the lockfile is just the CLI's bookkeeping.

## Profiles

The machine profile follows the OS: macs are `dev`, Linux hosts are `prod`.
`.zshenv` exports `MISE_ENV` accordingly, which selects the mise tool overlay
(`~/.config/mise/config.dev.toml`) and the starship config
(`starship-dev.toml` / `starship-prod.toml`). Prod hosts additionally skip
dev-only configs via `.chezmoiignore`.

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
