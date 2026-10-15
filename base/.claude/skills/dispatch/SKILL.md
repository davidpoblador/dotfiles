---
name: dispatch
description: Hand a piece of work to a detached background Claude session homed in a chosen directory, so the research or build happens outside this session's context. Use when David asks to do something "in the background", to "spin up a session" or "dispatch" work, or when a side quest would otherwise bury the thread we are on. Also use when the work belongs to a different repo than the one this session is in.
argument-hint: "[repo|path] what to work on"
allowed-tools: Bash(claude-bg-dispatch:*), Bash(claude agents:*), Bash(claude logs:*), Bash(mkdir:*), Write, ListAgents
---

# Dispatch work to a background session

A background session runs detached, with its own context, and keeps working
after this conversation moves on. Use it when the work is separable; keep the
work here when it is the thing David is watching.

Do not use this to parallelise a task you are already doing. One dispatched
session per piece of work.

## How to dispatch

**1. Pick the target directory.**

- An explicit repo name or path in the arguments wins.
- Otherwise the target is the directory this session is working in (`.`).
- If the work plainly belongs to another repo, say which and use that.

A bare name resolves under `~/repos`, so `--repo myproject` works.

**2. Name the session** after the subject in kebab-case (`tls-handshake-failure`),
never after a date or a ticket number. The name is how `claude agents`, `claude
attach` and `claude logs` find it.

**3. Write the brief to a file**, in your scratchpad directory.

This is the part that decides whether the dispatch is any use. The session
starts with **no context from this conversation**: it gets the brief, plus the
target directory's own instructions, and nothing else. It cannot see what we
have been doing, what we tried, or what David said.

So the brief carries, in its own words:

- the question or task, stated so it stands alone;
- every path, URL, id, command, version and finding from this conversation it
  would otherwise have to rediscover;
- what has already been ruled out, so it does not walk back in;
- what "done" looks like.

**Never put a secret in a brief.** It becomes process arguments and is stored in
`~/.claude/jobs/<id>/state.json`. Name the secret and let the session fetch it
(`fnox get NAME`, or `fnox exec`).

Then add these lines, adjusted for the names in play:

> You are the top-level owner of this work, not a helper. Follow this repo's own
> instructions in full, including any worktree, commit and index conventions
> they define.
>
> Push your work and open a PR, then stop. Do not merge: David decides on the
> content.
>
> When you are done or blocked, call ListAgents, then SendMessage to the session
> named `<this session's name, from ListAgents>` with a two-line summary and the
> PR link. Do not wait for a reply. If no session is listed under that name, send
> a PushNotification instead.

**4. Dispatch it.** `--add-dir` for each directory outside the target that the
work genuinely needs to read:

```bash
claude-bg-dispatch --repo <target> --name <session-name> --brief <brief-file> [--add-dir <path>]
```

If it reports that the directory is not a trusted workspace, tell David which
directory it is and what granting trust would allow (repository-supplied
`permissions.allow`, `.mcp.json` servers, subagent hooks), and let him run
`claude-trust-workspace`. Do not run it for him.

**5. Report and let go.** Give David the id and the three commands that reach it:

```
claude logs <id>      what it has been doing
claude attach <id>    open it here and talk to it
claude stop <id>      end it
```

Then carry on with what this session was doing. **Do not poll it** and do not
wait for it: it reports back through `SendMessage` on its own. Polling defeats
the purpose, which was to keep this context clear.

## Checking on them later

| Command | Shows |
|---|---|
| `claude agents` | the dashboard, all sessions |
| `claude agents --json` | the roster, without needing a TTY |
| `claude logs <id>` | recent terminal output (raw, with escape codes) |
| `claude rm <id>` | delete a session that has already exited |

`~/.claude/jobs/<id>/state.json` has the machine-readable view: `state`, a live
one-line `detail`, token count, cwd, and the original brief as `intent`.

A session whose `state` is `blocked` wants attention, often with an unsent
prompt in its box. It is not stuck, and it is not failing; `claude attach <id>`
and answer it.

## What dispatching does to the machine

The first dispatch after a reboot starts the per-user supervisor daemon. It
adopts every background session already running, and respawns stale ones onto
the current Claude Code version, which restarts those processes (their
conversations survive). So dispatching can briefly disturb an unrelated session.
The session hosts themselves are reparented to `init` and outlive both the
daemon and whichever session dispatched them.
