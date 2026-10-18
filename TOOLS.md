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
| poppler | PDF toolkit: pdftotext, pdfimages, pdftoppm |
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
| macwhisper | Local Whisper transcription (cask) |

#### Apps (casks)

| Package | Description |
|---|---|
| bitwarden | Password manager |
| docker-desktop | Docker Desktop (ships the docker CLI and shell completions) |
| gitkraken-cli | GitKraken terminal UI |
| ngrok | Tunnel local ports to public URLs |
| obsidian | Markdown-based knowledge base |
| raycast | Launcher / Spotlight replacement |
| responsively | Multi-viewport browser for responsive dev |
| vlc | Media player |


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

Reach for mise's `github` backend instead when the upstream publishes GitHub
release binaries, which is what the tap's formula usually downloads anyway. It
reads those releases directly and sidesteps the Homebrew API. `resend` and
`vacant` are installed that way; see the mise tool list.

Do not reach for `ubi:`. It is deprecated and goes away in mise 2027.1.0.
Porting an entry across the two means translating the options, not just the
prefix: `github:` has no `tag_regex`, and passing one is silently ignored
rather than rejected. To pick out one package's tags in a monorepo, use
`version_prefix` — `vacant` needs `version_prefix=vacant-v` so that `latest`
skips the `vacant-js-*` and `vacant-py-*` tags, which publish no binaries.

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

Most of these have their own installer wired into a `run_` script or `.zshrc`;
Rex is a plain manual download.

| Tool | Install method | Description |
|---|---|---|
| mise | curl (`mise.jdx.dev`) | Dev tool version manager |
| antidote | mise bootstrap (git repo) | Zsh plugin manager |
| alltuner | uv tool via bootstrap task | Internal CLI from `alltuner/infrastructure` |
| Rex | Manual download (Superlogical) | Terminal multiplexer and the terminal itself (see below) |

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
| gemini-cli | Google Gemini CLI (declared `npm:@google/gemini-cli`; the bare registry alias fails to build node-pty) |
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

Prefer backends in this order: **core** (built-in) > **aqua** / **github** (single binary download) > **asdf** (legacy plugin). Core/aqua/github install cleanly. `asdf:` plugins refresh their git repo on every `mise install`/`upgrade`, adding one line of noise per apply — fine for a tool you need, annoying for orphans.

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
| `dfb` | `mise bootstrap --yes --skip-dirty` (full converge) |
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
| `digs <topic>` | Start a background dig in the research workbench |


### Background Claude sessions

`claude --bg` starts a detached session that keeps working after the terminal or
the conversation that launched it moves on. `claude agents` lists them, `claude
attach <id>` opens one, `claude logs <id>` shows its recent output, and `claude
stop` / `claude rm` end and delete it.

The point of dispatching work this way is that the research or the build happens
in its own context, so it never crowds out the session that asked for it.

`claude-bg-dispatch` (in `base/.local/bin`) wraps the launch:

```bash
claude-bg-dispatch --repo <path|name> --name <session-name> --brief <file> [--add-dir <path>]
```

It exists because of four things that are not obvious:

- **There is no flag for the working directory.** A backgrounded session
  inherits the directory it was launched from, and `claude agents --cwd` only
  filters the listing. So the target is set by launching from it. The session
  then loads *that* directory's project instructions, not the caller's.
- **`--add-dir` is variadic**, so a prompt written after it is parsed as one
  more directory. The session comes up correctly homed and completely idle,
  which the launch line reports as `(idle — send a prompt to start)`. A `--`
  before the prompt ends the list.
- **The target must be a trusted workspace.** A directory never opened
  interactively is refused outright. Trust resolves through the containing git
  repository, so a nested repo inside a trusted one needs its own grant;
  `claude-trust-workspace <path>` gives it without the dialog.
- **The brief goes in a file.** A real brief is several paragraphs, and a
  dispatched session starts with no context beyond the brief and the target's
  own instructions, so it has to be self-contained. A file keeps all of that out
  of shell quoting. It is also why a brief must never contain a secret: it lands
  in the process arguments and in `~/.claude/jobs/<id>/state.json`.

#### Starting one

| Way in | Use it when | Cost |
|---|---|---|
| `digs <topic>` | A topic off the top of your head, from a terminal. Names the session after the topic | instant |
| `/dig <topic>` | The same, from inside a session already doing something else | two tool calls |
| `/dig-context <topic>` | The question only makes sense given what that session has been doing: what was tried, what broke, what was ruled out | as long as writing it down takes |
| `/dispatch [repo\|path] <task>` | Anything that is not a dig. Defaults to the directory the calling session is in; a bare name resolves under `~/repos` | two tool calls |

The three skills live in `base/.claude/skills/`; SKILLS.md carries the rule they
share about which context is worth handing over and which the dispatched session
should go and read for itself.

`/dig` is cheap because it dispatches **blind**: it looks nothing up, since the
session lands in the workbench and reads it faster than a caller can read it on
its behalf. The first version asked for a rich brief instead, and the calling
session spent nearly four minutes researching, in the one context the dispatch
existed to protect.

#### What an unattended session does

Nobody is watching a background session, which changes what it is safe for it to
decide. Launched through the skills, its brief tells it to stop at a PR rather
than merge, to assume rather than ask, and to report back when done. Worth
knowing because none of those are the defaults:

- **It will merge its own work if nothing stops it.** A repo whose instructions
  say to ship gets its PRs squash-merged by the session itself, with nobody
  having read them. One did exactly that, across two repos. The skills' briefs
  override the repo's shipping rule for this reason. `digs <topic>` sends **no
  brief at all**, so a terminal-launched dig still has that authority.
- **A question stalls it indefinitely.** There is nobody to answer, so it sits
  at `blocked` until attached. The briefs tell it to take the sensible reading
  and record the assumption instead.
- **It cannot be handed a file**, only a path to one. Anything bulky (a
  transcript, a log, a dump) goes in a file inside the target or an `--add-dir`
  directory.

Other limits, none fatal, all surprising once:

- **Session names are not unique.** Two dispatches with the same `--name` both
  succeed silently, and then neither resolves by name: `claude logs <name>`
  reports the clash and makes you use the ids.
- **Model and effort come from the settings**, not from the dispatching
  conversation. Pass `--model` to override.
- **The return channel is best-effort.** If the dispatching session has ended by
  the time the work finishes, its `SendMessage` lands nowhere. The PR is the real
  deliverable; the message is a convenience.
- **No budget ceiling.** `--max-budget-usd` applies only to `--print`, so a
  dispatched session runs until it finishes or `claude stop <id>`.
- **Exited sessions stay in the roster** until `claude rm <id>`, so the list
  accumulates. A reboot kills the processes; `claude respawn <id>` brings one
  back on the current version with its conversation intact.

Status, beyond `claude agents --json`, is in `~/.claude/jobs/<id>/state.json`:
`state`, a live one-line `detail`, tokens, cwd, and the original brief as
`intent`. A `state` of `blocked` means the session wants attention, commonly an
unsent prompt in its box, not that it has failed.

The first dispatch after a reboot starts the per-user supervisor daemon, which
adopts the background sessions already running and respawns stale ones onto the
current Claude Code version. That restarts those processes, though their
conversations survive. The daemon is spawned by the dispatching session's own
`claude` process rather than by a tool subshell, so it runs from `$HOME` with a
clean environment, and the session hosts it supervises are reparented to `init`,
which is how a fresh daemon adopts them.


### Browser automation setup

Which stack to use for what lives in `base/.agents/AGENTS.md`. This is the
one-time setup per machine.

#### Claude in Chrome

1. Install the [Claude in Chrome](https://chromewebstore.google.com/detail/claude/fcoeoabgfenejglbffodgkkbkcdhcgfn)
   extension (works with Chrome and Edge).
2. Start Claude Code with `claude --chrome`. The native messaging host config is
   installed automatically on first use.
3. To keep it on by default, run `/chrome` and choose "Enabled by default" (this
   keeps the browser tools loaded, which costs context).

#### Chrome DevTools MCP

It lives in `~/.claude.json` under `mcpServers`, which is machine-local and not
tracked here, so reproduce it by hand on each machine:

```jsonc
"chrome-devtools": {
  "type": "stdio",
  "command": "npx",
  "args": [
    "-y", "chrome-devtools-mcp@latest",
    "--autoConnect",                 // attach to the running Chrome, don't launch one
    "--usageStatistics=false",       // Google telemetry, on by default
    "--performanceCrux=false",       // stops trace URLs going to Google's CrUX API
    "--redactNetworkHeaders",        // keeps auth headers out of the transcript
    "--screenshotFormat=webp",       // ~3-5x smaller than the PNG default
    "--screenshotMaxWidth=1280",
    "--ignoreDefaultChromeArg=--enable-automation",
    "--chromeArg=--disable-blink-features=AutomationControlled"
  ]
}
```

`npx`, not `bunx`: `bunx pkg@latest` resolves `latest` once and then serves that
cached version forever, so the pin silently rots.

`--autoConnect` needs Chrome 144+ with remote debugging enabled once via
`chrome://inspect/#remote-debugging`. It attaches to the same Chrome the native
integration drives, so both stacks share state and there's only one window. The
last two args only apply when the server launches Chrome itself, so under
`--autoConnect` they're inert; they're kept as a fallback for the launch path,
where the `--chromeArg` is load-bearing for `navigator.webdriver`.

#### Safari Technology Preview

`safaridriver --mcp` exists only in Safari Technology Preview; stable Safari's
`safaridriver` has no such flag. STP comes from the declared
`brew-cask:safari-technology-preview`, which is a pkg installer rather than an
app bundle, so it runs `/usr/sbin/installer` under `sudo` and prompts for a
password. That means `mise bootstrap` cannot converge it over a plain ssh
session (`sudo: a terminal is required to read the password`) — install it from
a real terminal on the machine. Background maintenance never trips over this:
`dotfiles-maintain` upgrades formulae only.

Two steps follow the install. `--enable` also wants the password, so it is
local-terminal only; the `add-json` works fine over ssh.

```sh
/Applications/Safari\ Technology\ Preview.app/Contents/MacOS/safaridriver --enable
claude mcp add-json -s user safari-mcp-stp '{"type":"stdio","command":"/Applications/Safari Technology Preview.app/Contents/MacOS/safaridriver","args":["--mcp"]}'
```

`--enable` ticks "Enable Remote Automation" in the Develop menu, which is what
lets later WebDriver sessions start without authenticating each time. STP's own
`safaridriver` carries both `--enable` and `--mcp`; the system one at
`/usr/bin/safaridriver` has `--enable` but no `--mcp`.

Upgrading STP in place is safe for the config: a server started after the pkg
upgrade connects normally. Sessions holding an open safaridriver still need a
restart to pick the new binary up.

### Rex setup

Rex has no Homebrew cask, so it cannot go in `[bootstrap.packages]` and a fresh
mac needs these three steps by hand. (`brew info rex` is Rexify, an unrelated
Perl tool. Don't install it.)

1. Install **Rex Beta.app** from Superlogical into `/Applications` (no public
   download URL to record here yet). The app bundles its own server under
   `~/Library/Application Support/com.superlogical.rex/RexServer/Versions/<n>/`
   and updates itself, so there is nothing to pin.
2. `rex skill setup` — installs the agent skill and the SessionStart hook into
   every agent it finds (Claude Code, Codex, OpenCode, Pi). Both are generated
   from `rex __internal skill` on each use, so upgrading Rex updates what agents
   are told. `rex skill status` reports what is installed.
3. `rex terminfo setup` — installs the `xterm-rex` terminfo entry and the per-host
   ssh guard. `rex terminfo host` adds the entry to a remote machine; `rex terminfo
   status` reports what TERM a new terminal would get.

Only the Claude Code half of step 2 is tracked here: the SessionStart hook line
in `base/.claude/settings.json` arrives with the dotfiles, so Claude Code knows
its Rex session on a fresh machine before `rex skill setup` ever runs. The skill
files and Codex's `~/.codex/hooks.json` do not, because Rex rewrites them.

What the dotfiles contribute on top:

- `dev/.ssh/config` includes `~/.config/rex/ssh_config` (Rex-owned, holds the
  per-host records) and downgrades TERM for everything Rex has no record of.
- `base/.claude/hooks/user-prompt-split.sh` makes `:t` split the agent's own
  block at its cwd via `rex split`.

`~/.config/rex/` holds Rex's state: `ssh_config`, `terminfo-hosts`, and
`init.lua` once there are keybindings to set (`rex config check` validates it,
`rex config reload` re-reads it). None of it is tracked.

### MCP servers

User-scope servers live in `~/.claude.json` under `mcpServers`. That file is
machine-local and not tracked here (Claude Code rewrites it constantly, and it
holds the account identity), so each server is added per machine with
`claude mcp add`. A `mcpServers` key in the tracked `~/.claude/settings.json`
does nothing; `managedMcpServers` is the only settings key that defines
servers, and it works in enterprise-managed settings only.

The tracked route is a plugin: a plugin ships a plain `.mcp.json` at its root
(`{"mcpServers": {…}}`, same shape as above), so enabling it in
`enabledPlugins` gives every machine its servers on install. That is where the
cloudflare and resend servers come from. OAuth stays per machine either way.

```sh
claude mcp add -s user --transport http superlogical https://www.superlogical.com/rex/community-mcp
```

Superlogical is OAuth-gated, so after adding it run `/mcp` in a session on that
machine and authenticate; the tools stay behind an `authenticate` call until
you do. The token is per machine, like the config.

The other servers worth having on every dev machine are `chrome-devtools` and
`safari-mcp-stp`; their entries and setup are in the two sections above.
