# Production Dotfiles: Scoping

## Host inventory

4 production Linux hosts, all Ubuntu 24.04 x86_64, bash shell.

| Host | Packages (manual) | Primary use |
|---|---|---|
| host-a | 142 | Docker infra, syncthing |
| host-b | 142 | Docker infra, syncthing, networking |
| host-c | 142 | Docker infra, system admin |
| host-d | 49 | Docker infra, Claude Code, syncthing |

host-a/b/c are nearly identical (136 packages in common).
host-d is a leaner install (49 manual packages) but same workflow pattern.

## Tools already installed on all hosts

- **git**, **gh** (via apt, versions vary: 2.86-2.89)
- **tailscale** (via apt repo)
- **docker** (docker-ce, compose plugin, buildx)
- **vim**, **curl**, **wget**
- **python3** 3.12.3

On host-a/b/c only (not host-d): htop, tmux, rsync, screen

## Missing tools (wanted on all)

| Tool | Install method | Why |
|---|---|---|
| **uv** | `curl -LsSf https://astral.sh/uv/install.sh \| sh` | Python package management, same as dev |
| **starship** | `curl -sS https://starship.rs/install.sh \| sh` | Distinctive prod prompt |

gh and tailscale are already present via apt on all hosts. No action needed.

## Actual usage patterns (from shell history)

| Category | Commands | Frequency |
|---|---|---|
| Docker | `docker compose up/down/restart`, `docker ps`, `docker logs`, `docker exec`, `docker inspect` | #1 activity |
| Navigation | `ls`, `ls -la`, `l` (fails, not aliased), `cd`, `cat`, `more` | #2 activity |
| Git | `git pull`, `git grep` | Pull-only, no commits |
| Editing | `vi`, `vim` | Compose files, configs, .env |
| System | `sudo apt update/upgrade`, `sudo reboot`, `ps aux` | Maintenance |
| Networking | `tailscale status`, `nc -zv`, `ping`, `dig` | Debugging |
| Claude Code | `claude --dangerously-skip-permissions` | On host-d |

Notable: `l` is used on every host but is not aliased (fails silently or errors).

## Package drift between hosts

### host-a/b/c differences (from 136 common base)

| Package | host-a | host-b | host-c | Action |
|---|---|---|---|---|
| build-essential | yes | no | no | Keep on host-a only (build host) |
| cmake | yes | no | no | Keep on host-a only |
| rclone | yes | no | no | Keep on host-a only |
| reptyr | yes | no | no | Useful everywhere, add to common |
| iotop | yes | no | no | Useful everywhere, add to common |
| mosh | no | no | yes | Useful everywhere, add to common |
| man-db | no | yes | yes | Useful everywhere, add to common |
| net-tools | no | yes | yes | Useful everywhere, add to common |
| nano | no | yes | yes | Skip (vim is the editor) |

### host-d unique packages

| Package | Notes |
|---|---|
| jq | Useful, add to common |
| dnsmasq | Host-specific, keep |
| speedtest-cli | Host-specific, keep |
| tcpdump | Useful everywhere, add to common |
| pppoeconf/ppp | Host-specific networking, keep |

## What to deploy

### 1. Bash config (`.bashrc` / `.bash_aliases`)

- **History**: large size, timestamps, dedup, shared across terminals
- **EDITOR**: vim
- **Aliases**:
  - `l` = `ls -la` (used on all hosts, currently fails)
  - `..`, `...` = cd navigation
  - `gs` = `git status`, `gpl` = `git pull`
  - `dps` = formatted `docker ps`
  - `dlogs <name>` = `docker logs -f --tail 100`
  - `dexec <name>` = `docker exec -it <name> /bin/sh`
  - `dcu` / `dcd` = `docker compose up -d` / `docker compose down`
  - `dcr` = `docker compose restart`

### 2. Starship prompt (prod-specific config)

Distinct from dev prompt:
- Red/warm background for hostname (screams "this is production")
- Show hostname prominently (which server am I on?)
- Git branch (when in a repo)
- Command duration (spot slow operations)
- No language versions, no docker context, no cloud accounts
- Compact single-line format

### 3. Common apt packages to sync

```
reptyr mosh man-db net-tools iotop jq tcpdump htop tmux rsync
```

### 4. Tools via standalone installers

| Tool | Install |
|---|---|
| uv | Standalone installer, no apt repo needed |
| starship | Standalone installer, no apt repo needed |

## Repo strategy

Same repo, separate `prod/` directory. No chezmoi on prod hosts.

```
dotfiles/
  dot_zshrc                              # dev (existing)
  private_dot_config/                    # dev (existing)
  run_onchange_darwin-install-packages.sh.tmpl
  prod/
    install.sh                           # Bootstrap script
    bashrc                               # Production .bashrc
    starship.toml                        # Production starship config
    packages.txt                         # Common apt packages to sync
```

### Bootstrap workflow

```bash
# First time on a new prod host (repo is public, no auth needed):
curl -sS https://raw.githubusercontent.com/davidpoblador/dotfiles/main/prod/install.sh | bash
```

The script would:
1. Back up existing `.bashrc`
2. Deploy production `.bashrc`
3. Install starship if not present
4. Deploy production `starship.toml`
5. Install uv if not present
6. Install common apt packages (with sudo)
7. Print summary of what changed

Updating later:
```bash
prod-update   # alias in bashrc that re-runs the install script
```

## Next steps

1. Approve this scope
2. Build `prod/bashrc` with aliases and history config
3. Build `prod/starship.toml` with red/production theme
4. Build `prod/packages.txt` with common packages
5. Build `prod/install.sh` bootstrap script
6. Test on one host, then roll out to the rest
