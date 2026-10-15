---
name: dig
description: Start a dig, a self-contained investigation in David's research workbench at ~/repos/digs, as a detached background session. Use when he poses a research question, a "why does X do Y", a comparison, or a topic to look into that is not a change to the code in front of us, and when this session is NOT already inside ~/repos/digs. Use it also when he says to dig into something or to look into it in the background.
argument-hint: "the question or topic to dig into"
allowed-tools: Bash(claude-bg-dispatch:*), Bash(claude agents:*), Bash(claude logs:*), Bash(ls:*), Write, ListAgents
---

# Start a dig in the background

A dig is one investigation living in its own directory under `~/repos/digs`,
with the writeup and every script and artifact the work produced. The point is
that conclusions survive the conversation that produced them.

This skill only **starts** one somewhere else, so the research does not consume
the context of whatever this session is doing.

## When not to use this

**If this session is already working in `~/repos/digs`, stop and do not use
this skill.** That repo's own instructions tell the session that owns it to dig
in place, and dispatching from inside it would create a second owner for the
same work. Follow the repo's drill instead.

Likewise, if the question is really about the code in front of us, answer it
here. A dig is for a question with a life of its own.

## Dispatch in under a minute

**The investigation is the dispatched session's job, not yours.** It arrives in
the workbench with the directories you give it and orients itself there, with
its own context. So:

- **Do not research the subject before dispatching.** No reading the files the
  question is about, no grepping for background, no checking memories, no
  WebSearch, no advisor call. If you catch yourself learning something about the
  question, stop and dispatch.
- **One lookup is allowed**: listing the workbench's digs, to find an existing
  slug. Nothing else.
- Anything you think the session needs to find out goes in the brief as **an
  instruction to go look**, not as a result you fetched for it.

A cold question should be dispatched in about three steps: list the digs, write
the brief, launch. If you are on your fifth tool call and have not launched yet,
you have taken over the dig instead of handing it off, and the point of this was
to keep this session's context clear.

## How

**1. Pick the slug.** It names the *subject*, in kebab-case, and nothing else:
no date, no status, no "new" or "v2" (`dns-resolution-timeouts`, not
`2026-01-02-dns-bug`). A dig is a living thing David returns to, so its path has
to stay stable. Check what already exists first:

```bash
ls ~/repos/digs/notes
```

If a dig on the subject is already there, the work is a **new angle on that
dig**, not a new one. Say so in the brief and use the existing slug.

**2. Write the brief to a file** in your scratchpad directory.

The dispatched session starts with no context from this conversation. It will
read the workbench's own instructions when it gets there, so **do not restate
them**: nothing about templates, worktrees, frontmatter, the index or how to
commit. Those live in the repo and change there.

The brief carries what **this conversation already contains**, and nothing you
would have to go and find:

- the question, stated so it stands alone, in David's words where he gave them;
- why it came up, and what would count as an answer;
- whatever we have already established here: paths, URLs, commands, versions,
  error messages, dead ends. If the question arrived cold and we have discussed
  nothing, this list is empty, and that is fine.
- the existing slug, if this is a new angle on a dig that already exists;
- where to start looking: the repos, directories and files worth reading, **as
  pointers, not as content you fetched**.

A cold question makes a short brief. Resist padding it: a long brief built from
research you just did means you did the dig in the wrong session.

**Never put a secret in a brief.** It becomes process arguments and is stored in
`~/.claude/jobs/<id>/state.json`. Name it and let the session fetch it with
`fnox`.

Then add these lines:

> You are the top-level owner of this dig, not a helper. Follow the workbench's
> own instructions in full: start the dig, manage its worktree, commit as you
> go, and regenerate the index.
>
> Orient yourself before you conclude anything: read what the directories above
> actually contain rather than relying on this brief, which was written without
> looking at them.
>
> Push and open a PR, then stop. Do not merge: David decides on the content.
>
> When you are done or blocked, call ListAgents, then SendMessage to the session
> named `<this session's name, from ListAgents>` with a two-line summary and the
> PR link. Do not wait for a reply. If no session is listed under that name, send
> a PushNotification instead.

**3. Dispatch it**, naming the session after the slug:

```bash
claude-bg-dispatch --repo digs --name <slug> --brief <brief-file>
```

**Always pass `--add-dir` for the repo this session is standing in**, when the
question came out of it: the dispatched session is homed in the workbench and
cannot read that repo otherwise, and this is what replaces you reading it for
them. Add one for any other directory the investigation needs: a sibling repo,
a log directory, a checkout being compared.

**4. Report** the id, with `claude logs <id>` / `claude attach <id>` / `claude
stop <id>`, and go back to what this session was doing. Do not poll it; it
reports back on its own.

## Several at once

Parallel digs are fine, and the sessions do not collide: each works in its own
worktree. They do all regenerate the same index in `README.md`, so **their PRs
conflict with each other** and have to be merged one at a time, oldest first,
each one rebased or reindexed after the previous merge.

`claude agents` lists them. The full mechanics of background sessions, including
how trust and `--add-dir` behave, are in the `dispatch` skill.
