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

## Dispatch first, do not pre-investigate

**The work is the dispatched session's job, not yours.** It arrives in the target
directory, reads that directory's instructions, and can see every path you give
it with `--add-dir`. It does not need you to go ahead of it.

So before launching: no reading the files the task is about, no grepping for
background, no checking memories, no WebSearch, no advisor call. If you catch
yourself learning something about the task itself, stop and launch.

Whatever you believe the session needs to find out goes in the brief as **an
instruction to go look**, not as a result you fetched for it. A cold request
should be dispatched in two or three steps: write the brief, launch, report. If
you are on your fifth tool call and have not launched, you have taken the work
over instead of handing it off, which was the opposite of the point.

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

So the brief carries what **this conversation already contains**, and nothing
you would have to go and find:

- the question or task, stated so it stands alone;
- paths, URLs, ids, commands, versions and findings already established here, so
  it does not rediscover them. If the request arrived cold, there are none, and
  the brief is correspondingly short;
- what has already been ruled out, so it does not walk back in;
- where to start looking, **as pointers rather than as content you fetched**;
- what "done" looks like.

If the material is bulky (a pasted document, a transcript, a log, an error dump),
**put it in a file** inside the target directory or a directory you pass with
`--add-dir`, and point the brief at that path. A brief is a prompt, not an
attachment, and the session has no other way to receive a file.

**Never put a secret in a brief.** It becomes process arguments and is stored in
`~/.claude/jobs/<id>/state.json`. Name the secret and let the session fetch it
(`fnox get NAME`, or `fnox exec`).

Then add these lines, adjusted for the names in play:

> You are the top-level owner of this work, not a helper. Follow this repo's own
> instructions in full, including any worktree, commit and index conventions
> they define.
>
> Orient yourself before you conclude anything: read what the directories above
> actually contain rather than relying on this brief, which was written without
> looking at them.
>
> Nobody is watching this session. Do not ask questions and do not wait for an
> answer: where something is ambiguous, pick the sensible reading, say so in what
> you write up, and carry on. If you are truly blocked, stop and report rather
> than sitting idle.
>
> Push your work and open a PR, then **stop there**. Do not merge, and do not run
> the shipping command that merges, even where this repo's instructions say to
> ship: David has not seen this work, because you are running detached and he was
> not in the conversation that started you. The PR is where you hand it to him.
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

Exited sessions stay in the roster until `claude rm`, so the list accumulates.
A reboot kills the session processes; `claude respawn <id>` restarts one on the
current version, keeping its conversation.

## Known limits

- **Names are not unique.** Dispatching twice with the same `--name` is accepted
  silently, and then neither one resolves by name: `claude logs <name>` reports
  the clash and makes you use the ids. Do not spend a call checking, but pick a
  distinct name when you know something is already running on the subject.
- **Model and effort come from the settings, not from this conversation.**
  Whatever this session is running on now does not carry over. Pass `--model` if
  the work needs a particular one.
- **The return channel is best-effort.** If the dispatching session has ended by
  the time the work finishes, the `SendMessage` lands nowhere, which is why the
  brief falls back to a push notification. Neither is guaranteed, so for work
  that matters the PR is the real deliverable, not the message.
- **No budget ceiling.** A dispatched session runs until it is done or stopped;
  `--max-budget-usd` only applies to `--print`. `claude stop <id>` is the brake.

## What dispatching does to the machine

The first dispatch after a reboot starts the per-user supervisor daemon. It
adopts every background session already running, and respawns stale ones onto
the current Claude Code version, which restarts those processes (their
conversations survive). So dispatching can briefly disturb an unrelated session.
The session hosts themselves are reparented to `init` and outlive both the
daemon and whichever session dispatched them.
