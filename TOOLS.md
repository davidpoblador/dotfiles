# Tools

### Homebrew packages

Declared in `mise.dev.toml` (`[bootstrap.packages]`), installed by
`mise bootstrap` on macs. Add one with `mise bootstrap packages use
brew:<name>` (or `brew-cask:`) after checking `brew info <name>`; remove with
`packages prune` after deleting the entry.

#### Shell and terminal

| Package | Description |
|---|---|
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
| mole | Deep clean and optimize macOS |
| mosh | Latency-tolerant SSH replacement |
| potrace | Trace bitmaps into vector graphics |
| pv | Pipe progress meter |
| qrencode | QR code generator |
| rsync | File sync |
| sc-im | Terminal spreadsheet editor |
| shfmt | Shell script formatter |
| silicon | Code screenshot generator |
| telnet | Telnet client |
| tokei | Code stats by language |
| tree | Directory listing |
| typst | Markup-based typesetting system |
| watchexec | Run commands on file changes |
| watchman | File-watching service (RN / Xcode tooling) |
| wget | HTTP client |
| yq | YAML/XML/TOML processor |
| yt-dlp | Video downloader |
| zbar | Barcode and QR reader |

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
| node | JavaScript runtime for tooling that needs system node |
| protobuf | Protocol Buffers compiler |
| sentencepiece | Text tokenizer |

#### Apple platform development

| Package | Description |
|---|---|
| cocoapods | Dependency manager for Cocoa projects |
| xcodegen | Generate Xcode projects from a spec |

#### Git

| Package | Description |
|---|---|
| git | Version control (newer than macOS ships) |
| git-absorb | Auto-fixup staged changes into prior commits |
| tig | Git text-mode interface |

#### AI tooling

| Package | Description |
|---|---|
| rtk | CLI proxy that minimizes LLM token consumption |
| macwhisper | Local Whisper transcription (cask) |

#### Apps (casks)

| Package | Description |
|---|---|
| bitwarden | Password manager |
| docker-desktop | Docker Desktop (ships the docker CLI and shell completions) † |
| gitkraken-cli | GitKraken terminal UI |
| ngrok | Tunnel local ports to public URLs † |
| obsidian | Markdown-based knowledge base |
| raycast | Launcher / Spotlight replacement † |
| responsively | Multi-viewport browser for responsive dev |
| vlc | Media player † |

† installed by the bootstrap task through the brew CLI: mise's cask shim
cannot handle these (see TODO.md and jdx/mise#11107).

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

#### Third-party tap formulae

`[bootstrap.packages]` resolves `brew:` entries against the Homebrew API and
will not proxy to the `brew` CLI, so a formula from a tap that doesn't publish
`api/formula/<name>.json` cannot be declared at all — not even tap-qualified.
Nothing is currently installed that way.

Reach for mise's `ubi` backend instead when the upstream publishes GitHub
release binaries, which is what the tap's formula usually downloads anyway. It
reads those releases directly and sidesteps the Homebrew API. `resend` and
`vacant` are installed that way; see the mise tool list.

`mise bootstrap packages prune` judges against the *current* formula metadata,
so it also surfaces dependencies that a locally installed formula still links
but its formula no longer declares. `brew outdated` stays silent about these,
because the version is unchanged and only the dependency graph moved.

When prune lists a library you didn't install directly, check what still needs
it before doing anything:

```bash
brew uses --installed <formula>
```

If something does, that parent is a stale build: `brew reinstall <parent>`
rebuilds it against the current dependencies, after which the library really is
an orphan and comes off cleanly. `the_silver_searcher` had been built against
`pcre` while the formula had moved to `pcre2`, and `cairo` against
`python-setuptools` which it no longer needs.

Read `--dry-run` first regardless — a tap formula that cannot be declared also
shows up here, and that is a different problem with a different answer.

### Installed outside Homebrew and mise

Each of these has its own installer wired into a `run_` script or `.zshrc`.

| Tool | Install method | Description |
|---|---|---|
| mise | curl (`mise.jdx.dev`) | Dev tool version manager |
| antidote | mise bootstrap (git repo) | Zsh plugin manager |
| alltuner | uv tool via bootstrap task | Internal CLI from `alltuner/infrastructure` |

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
| codex | OpenAI Codex CLI |
| uv | Python package manager |
| zoxide | cd replacement (z) |

Dev profile only:

| Tool | Description |
|---|---|
| actionlint | GitHub Actions linter |
| awscli | AWS CLI |
| cf | Cloudflare CLI |
| age | File encryption (fnox identity format) |
| claude | Claude Code CLI |
| copilot-cli | GitHub Copilot CLI |
| fnox | Secrets manager |
| gcloud | Google Cloud SDK |
| gemini-cli | Google Gemini CLI |
| gopls | Go language server |
| mise-completions-sync | Auto-sync mise tool completions to zsh |
| mongosh | MongoDB shell |
| opencode | Open-source terminal coding agent |
| prek | Git hook manager (pre-commit alternative) |
| resend-cli | Resend email CLI |
| ruff | Python linter and formatter |
| rust | Rust programming language |
| rust-analyzer | Rust language server |
| sentry-cli | Sentry release and sourcemap CLI |
| stripe | Stripe CLI |
| ty | Python type checker |
| vacant | Domain availability checker via authoritative DNS |
| vhs | Scripted terminal session recorder |
| zig | Zig programming language |

Mise also auto-installs dependencies on `cd`: runs `uv sync` when `uv.lock` exists without `.venv`, and `bun install` when `bun.lock` exists without `node_modules`.

#### Adding a new mise tool

```bash
mise registry <tool>    # see which backends are available
mise use -g <tool>      # install + add to global config
# then: move the pin from ~/.config/mise/config.toml into the repo copy
# (it is a symlink into the repo, so mise use -g already edited it in place)
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
| `dfu` | pull + `mise dotfiles apply` (sync this machine) |
| `dfs` | `mise dotfiles status` |
| `dfb` | `mise bootstrap --yes` (full converge) |
| `dfa` | `mise dotfiles apply` (repo-scoped) |
| `dfc` | `cd ~/repos/dotfiles` |
| `bubu` | `brew update && brew upgrade --formula --yes` |
| `apu` | `sudo apt update` (Linux) |
| `apg` | `sudo apt upgrade` (Linux) |

### Shell functions

| Function | Description |
|---|---|
| `gac <msg>` | `git add . && git commit -m <msg>` |
| `gnb <branch>` | Checkout main, pull, create new branch |
| `cdm` | cd to main worktree of current git repo |
| `rep [name]` | cd to `~/repos` or `~/repos/<name>` |

