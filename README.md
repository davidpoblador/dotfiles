# Dotfiles

Personal dotfiles managed with [mise](https://mise.jdx.dev/) (`mise bootstrap` + `[dotfiles]`).

## Repo structure

| Path | What |
|---|---|
| `base/` | Dotfiles for **every** machine, mirroring their paths under `~` (one `symlink-each` entry in `mise.toml`: each file is individually symlinked, unmanaged files coexist) |
| `dev/` | Dotfiles deployed to **dev machines (macs) only**, via per-directory entries in `mise.dev.toml` |
| `mise.toml` | Bootstrap config for all machines: dotfiles mapping, repos, macOS defaults, launchd/systemd units, the imperative bootstrap task |
| `mise.dev.toml` | Dev-only additions, loaded when `MISE_ENV=dev`: brew/cask/mas packages, dev dotfile trees |
| `bootstrap.sh` | curl-able one-command machine setup |

## Fresh machine setup

One command on any machine (installs Homebrew on macs, installs mise, clones
the repo, and converges everything, login shell included):

```bash
curl -fsSL https://raw.githubusercontent.com/davidpoblador/dotfiles/main/bootstrap.sh | bash
```

It deploys configs as symlinks into the repo, installs all packages and mise
tools, seeds atuin with any pre-existing shell history, and installs the
`alltuner` CLI from the private `alltuner/infrastructure` repo (requires SSH
access to GitHub from the machine).

Platform notes:

- **macOS**: sign in to the App Store first (`mas` cannot accept first-time
  licenses non-interactively). To mosh into the Mac, the bootstrap task allows
  `mosh-server` through the application firewall automatically, using the
  resolved binary path since brew upgrades invalidate path-bound rules; it
  needs sudo, so run `mise bootstrap --only task` interactively once if mosh
  connections fail after a mosh upgrade.
- **Linux**: system packages (zsh, mosh, keychain) come from apt via
  `[bootstrap.packages]` — expect one sudo prompt. The bootstrap task enables
  systemd lingering so the maintenance timer runs unattended. Afterwards, log
  out fully and reconnect so the login shell change takes effect (with SSH
  multiplexing, close the shared connection first: `ssh -O exit <host>`).

## Day-to-day usage

```bash
dfu    # sync this machine: pull + apply (pull alone deploys edits; apply covers new/removed files)
       # (dfb also pulls the repo first: it manages itself via [bootstrap.repos])
dfs    # what would change (dotfiles status)
dfb    # full converge: packages, defaults, services, tools
dfc    # cd into the repo
dfa    # dotfiles apply only
bubu   # update Homebrew formulae by hand (apu/apg on Linux)
zbench # time shell startup, with a zprof breakdown
```

Everything else (mise tools, brew formulae, antidote, the skills mirror)
auto-updates daily via launchd/systemd timers running `dotfiles-maintain`.

### Managing files

- **Edit** a managed file: just edit it (live file and repo file are the same
  thing through the symlink), commit via PR, `git pull` on the other machines.
- **Add** a file: place it under `base/` (all machines) or `dev/` (macs),
  mirroring its path relative to `~`, then run `dfa`.
- **Remove** a file: delete it from the tree and remove the leftover symlink
  from `~` yourself (there is no state database).
- **Add a mac package**: `brew info <name>` first, then
  `mise bootstrap packages use brew:<name>` (or `brew-cask:`) — it writes the
  entry and installs in one step. If mise's cask shim rejects it
  (`auto_updates`, odd artifacts), add a guarded `brew install` to the
  bootstrap task instead.
- **Add a tool**: pin it in `base/.config/mise/config.toml` (all machines) or
  `config.dev.toml` (macs).

Two rules that bite: new scripts need `chmod +x` before committing (systemd
fails with 203/EXEC otherwise), and `mise dotfiles apply` must only run from
`~/repos/dotfiles` — never from a worktree, or every symlink bakes the
worktree path.

## What's managed

| Path | What |
|---|---|
| `.zshrc`, `.zsh_plugins.txt` | Shell config, plugins (antidote + zsh-defer) |
| `.config/mise/config.toml` | Global tools: bun, go, uv, ripgrep, etc. (+ `config.dev.toml`: rust, ruff, claude, …) |
| `.config/starship-{dev,prod}.toml` | Prompt (per profile) |
| `.config/ghostty/`, `.config/tmux/` | Terminal |
| `.config/git/`, `.gitignore_global` | Git config |
| `.config/gh/` | GitHub CLI |
| `.config/bat/`, `.config/lazygit/` | CLI tools |
| `.claude/` | Claude Code settings and hooks |
| `.agents/` | Shared `AGENTS.md`/`CLAUDE.md` and the generated cross-agent skills mirror |
| `.ssh/` | SSH config (no keys) |
| `.config/vim/vimrc` | Vim config |

## Tools

The full inventory (brew formulae, casks, App Store apps, mise tools, zsh
plugins, aliases and functions) lives in [TOOLS.md](TOOLS.md). Declarations:
packages in `mise.dev.toml`, tools in `base/.config/mise/config.toml`
(+ `config.dev.toml` for dev-only), zsh plugins in `base/.zsh_plugins.txt`.


## Secrets

[fnox](https://fnox.jdx.dev) manages secrets on dev machines (macs): age-encrypted values
live inline in `dev/.config/fnox/config.toml` (safe to commit), decrypted
with the Syncthing-distributed identity at `~/sync/secrets/keys.txt`
(`FNOX_AGE_KEY_FILE`, exported by `.zshenv` where the key exists). The daemon
caches resolved values in memory; shell integration loads project `fnox.toml`
secrets on `cd`.

```bash
fnox set -g NAME value       # encrypt into the global config (a repo symlink: commit it via PR)
fnox get NAME                # decrypt one value
fnox list                    # names only; add --values to decrypt all
fnox exec -- cmd args        # run a command with all secrets in its env
fnox edit -g                 # edit the global config with decrypted values
fnox reencrypt -p age        # after changing recipients
fnox daemon status|clear     # in-memory cache (auto-starts; clears on config change)
```

Per-project secrets go in a `fnox.toml` next to the code; the shell hook loads
them on `cd` and unloads on leave. Without `-g`, `fnox set` writes to
`./fnox.toml` — mind which one you mean.

sops + age stay available (dev machines) for repos that use them, e.g.
`~/repos/infrastructure`.

## Agent skills

Skills (reusable `SKILL.md` bundles) are declared as Claude Code **plugins** in
`~/.claude/settings.json` (`extraKnownMarketplaces` + `enabledPlugins`), which
is itself a managed dotfile — so the full set restores on any machine from the
declaration alone. Sources without an upstream marketplace are served by
[alltuner/skills](https://github.com/alltuner/skills), whose
`.claude-plugin/marketplace.json` pins them by commit sha via `git-subdir`.

Cross-agent sharing: `skills-mirror` (run by the bootstrap task and the daily
maintenance job) regenerates `~/.agents/skills/<name>` as symlinks into the
Claude Code plugin cache. Codex and pi read `~/.agents/skills` natively, so
every agent sees the same skills without any per-agent install step. The shared
`~/.agents/AGENTS.md` (with per-agent `AGENTS.md`/`CLAUDE.md` symlinks) is
unchanged.

To add a skill: enable an existing marketplace plugin in `settings.json`, or —
for a new source — add an entry to the alltuner/skills marketplace and enable
it. To remove one, delete its `enabledPlugins` line.

## Profiles

The machine profile follows the OS: macs are `dev`, Linux hosts are `prod`.
`.zshenv` exports `MISE_ENV` accordingly, which selects the mise tool overlay
(`~/.config/mise/config.dev.toml`) and the starship config
(`starship-dev.toml` / `starship-prod.toml`). Dev-only configs live in the
`dev/` tree, declared only in `mise.dev.toml`.

## Platform support

- **macOS**: Full dev environment with Homebrew packages, App Store apps, casks, fonts
- **Linux**: Production config with zsh, starship, and the full base mise toolset

## Wallpaper sync (macOS)

Keeps desktop wallpapers consistent across Macs via a Syncthing-backed
folder. Pairs each attached display with the file whose aspect ratio is
closest to the display's native aspect, using `--scale=fill` (preserve
aspect, cover screen, crop overflow).

### Setup

1. Share `~/sync/exchange/wallpapers/` across your Macs with Syncthing.
   The bootstrap task creates it and symlinks `~/Pictures/wallpapers` to it
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
