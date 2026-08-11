# Agent skills

Skills are `SKILL.md` bundles following the
[Agent Skills standard](https://agentskills.io/home). The *format* is portable —
Claude Code, Codex, Gemini CLI, opencode and pi all read the same file. The
*distribution* is not: every publisher blesses a different install path, so
there is no single command that covers them all.

This file records what is installed today and the blessed way to install each,
so the set can be rebuilt deliberately rather than accumulated.

## How agents find skills

`~/.agents/skills/<name>` is the shared location. Codex, Gemini CLI, opencode
and pi discover it natively, so a skill placed there needs no per-agent step:

| Agent | Reads |
|---|---|
| Codex | `$HOME/.agents/skills` |
| Gemini CLI | `~/.agents/skills` (alias for `~/.gemini/skills`) |
| opencode | `~/.agents/skills` |
| pi | `~/.agents/skills` |
| Claude Code | its own plugin cache — never `~/.agents/skills` |

Claude Code is the exception: it loads plugins directly. A skill can be given
to it through `~/.claude/skills/`, but **only if no plugin already provides it**
— otherwise it loads twice and burns context in every session.

## What is installed

All of it currently arrives as Claude Code plugins, declared in
`base/.claude/settings.json`.

### From the official marketplace — Claude Code only

`anthropics/claude-code-plugins` is **not a public repository** (`gh api` and a
plain fetch both 404). It is served through Claude Code's own channel, so these
cannot be installed by the skills CLI or copied by hand. Claude Code is the
only way to get them.

Installed: `frontend-design` (1 skill).

```
/plugin install frontend-design@claude-plugins-official
```

### cloudflare/skills — 11 skills

Four documented methods, none marked preferred. For Claude Code:

```
/plugin marketplace add cloudflare/skills
/plugin install cloudflare@cloudflare
```

For any other agent:

```bash
npx skills add https://github.com/cloudflare/skills
```

Ships commands and an MCP server alongside the skills: `agents-sdk`,
`cloudflare`, `cloudflare-email-service`, `cloudflare-one`,
`cloudflare-one-migrations`, `durable-objects`, `sandbox-sdk`,
`turnstile-spin`, `web-perf`, `workers-best-practices`, `wrangler`.

### resend/resend-skills — 5 skills

One documented method, which prompts for which skills to take:

```bash
npx skills add resend/resend-skills
```

Ships an MCP server. Skills: `resend`, `resend-cli`, `react-email`,
`agent-email-inbox`, `email-best-practices`.

### ast-grep/agent-skill — 2 skills

The README explicitly recommends the CLI over its own marketplace:

```bash
npx skills add ast-grep/agent-skill
```

Skills: `ast-grep`, `outline`.

### astral-sh/claude-code-plugins — 3 skills

Claude Code only; no CLI path is documented.

```
/plugin marketplace add astral-sh/claude-code-plugins
/plugin install astral@astral-sh
```

Skills: `ruff`, `ty`, `uv` — invoked as `/astral:<skill>`. Note their
`SKILL.md` files omit the `name` frontmatter field, so the skills CLI skips
them with a warning.

### pbakaus/impeccable — 1 skill

Blessed path is its own installer, which compiles a build for the detected
harness:

```bash
npx impeccable install     # update with: npx impeccable update
```

`npx skills add pbakaus/impeccable` also works but its docs call that "one
shared build for all harnesses rather than the one compiled for yours". The
Claude marketplace (`/plugin marketplace add pbakaus/impeccable`) is a third
option. Ships an agent alongside the skill.

### alltuner/skills — 2 skills

```bash
npx skills add alltuner/skills                 # both
npx skills add alltuner/skills --skill vacant  # one
```

`vacant` and `selfmail`. The marketplace publishes only skills written here —
it does not republish anyone else's.

## Documented, not installed by default

Useful, deliberately not enabled. Install when a project needs them, then
remove again.

| Skill set | Install |
|---|---|
| **expo** — 21 skills (`eas-*`, `expo-*`), agents, MCP server | `/plugin install expo@claude-plugins-official` |
| **stripe** — 7 skills, commands, agents, MCP server | `/plugin install stripe@claude-plugins-official` |
| **fastapi** | `npx skills add fastapi/fastapi --skill fastapi` |
| **shadcn** | `npx skills add shadcn/ui --skill shadcn` |
| **remotion-best-practices** | `npx skills add remotion-dev/skills` |
| **find-skills** | `npx skills add vercel-labs/skills --skill find-skills` |

expo and stripe are Claude Code only, for the marketplace reason above. The
other four are installed straight from their upstreams rather than through a
re-host.

## Adding a skill

Prefer the publisher's blessed path from the table above. Failing that, the
[skills CLI](https://github.com/vercel-labs/skills) is the general mechanism:

```bash
npx skills add <owner>/<repo> --global          # canonical copy in ~/.agents/skills
npx skills add <owner>/<repo> --global --skill <name>
```

It reads `.claude-plugin/marketplace.json` and `plugin.json`, so it can consume
Claude marketplaces — but only where the repository is publicly cloneable.

**Do not pass `--agent` targeting Claude Code for a skill a plugin already
provides.** That writes `~/.claude/skills/` and causes double-loading.

`~/.agents/.skill-lock.json` records CLI-installed skills. `experimental_install`
restores from a lockfile, but is project-scoped only — there is no global
restore, so a new machine needs the install commands re-run.

## Removing a skill

- Plugin-provided: delete its line from `enabledPlugins` and restart Claude Code.
  A plugin is all-or-nothing; its MCP server, commands and agents go with it.
- CLI-installed: `npx skills@latest remove <name> --global`

## Checking what an agent sees

```bash
ls ~/.agents/skills
codex exec "list the skills you can see"
npx skills@latest list --global
```
