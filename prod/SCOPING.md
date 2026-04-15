# Production Dotfiles: Scoping

## Scope

User-space shell configuration only. No system administration (apt packages,
tailscale, docker, etc.). Those are provisioned separately per host.

## Host inventory

4 production Linux hosts, all Ubuntu 24.04 x86_64, bash shell.

| Host | Primary use |
|---|---|
| host-a | Docker infra, syncthing |
| host-b | Docker infra, syncthing, networking |
| host-c | Docker infra, system admin |
| host-d | Docker infra, Claude Code, syncthing |

## Tools already available (system-level)

- git, gh, tailscale, docker (compose, buildx), vim, curl, wget, python3

## Actual usage patterns (from shell history)

| Category | Commands | Frequency |
|---|---|---|
| Docker | `docker compose up/down/restart`, `docker ps`, `docker logs`, `docker exec`, `docker inspect` | #1 activity |
| Navigation | `ls`, `ls -la`, `l` (fails, not aliased), `cd`, `cat`, `more` | #2 activity |
| Git | `git pull`, `git grep` | Pull-only, no commits |
| Editing | `vi`, `vim` | Compose files, configs, .env |
| System | `sudo apt update/upgrade`, `sudo reboot`, `ps aux` | Maintenance |
| Networking | `tailscale status`, `nc -zv`, `ping`, `dig` | Debugging |

Notable: `l` is used on every host but is not aliased (fails silently or errors).

## What to deploy

### 1. Bash config (`bashrc`)

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
- **`prod-update`**: alias that re-runs the install script to pull latest configs

### 2. Starship prompt (`starship.toml`)

Distinct from dev prompt:
- Red/warm background for hostname (screams "this is production")
- Show hostname prominently (which server am I on?)
- Git branch (when in a repo)
- Command duration (spot slow operations)
- No language versions, no docker context, no cloud accounts
- Compact single-line format

### 3. Mise config (`mise.toml`)

Stripped-down tool list for prod (user-space installs, no sudo):

```toml
[tools]
uv = "latest"
```

Add more tools here as needed. Mise itself is installed by the bootstrap script.

### 4. Bootstrap script (`install.sh`)

All user-space, no sudo required.

1. Install mise if not present (single curl, user-space binary)
2. Deploy `bashrc` to `~/.bashrc` (backs up existing)
3. Deploy `starship.toml` to `~/.config/starship.toml`
4. Deploy `mise.toml` to `~/.config/mise/config.toml`
5. Run `mise install` (installs starship, uv, and any other tools in the config)
6. Print summary of what changed

## Repo layout

Same repo as dev dotfiles, separate `prod/` directory. No chezmoi on prod hosts.

```
dotfiles/
  ...                                    # dev (existing chezmoi files)
  prod/
    SCOPING.md                           # This file
    install.sh                           # Bootstrap script
    bashrc                               # Production .bashrc
    starship.toml                        # Production starship config
    mise.toml                            # Production mise tool list
```

## Bootstrap workflow

```bash
# First time on a new prod host (repo is public, no auth needed):
curl -sS https://raw.githubusercontent.com/davidpoblador/dotfiles/main/prod/install.sh | bash

# Updating later:
prod-update
```

## Out of scope

- System packages (apt): managed during host provisioning
- Docker, tailscale, gh: installed at system level
- Agent skills: not needed on prod
- Zsh: bash is sufficient for prod ops

## Next steps

1. Approve this scope
2. Build `prod/bashrc` with aliases and history config
3. Build `prod/starship.toml` with red/production theme
4. Build `prod/mise.toml` with uv
5. Build `prod/install.sh` bootstrap script
6. Test on one host, then roll out to the rest
