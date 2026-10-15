---
name: dig-context
description: Start a dig that carries this conversation with it, for when the question only makes sense given what we have already been doing, discussing or debugging here. Use instead of `dig` when the work depends on decisions, errors, outputs or dead ends from this session that a fresh session could not find on its own, and when David says to bring the context along, hand over what we have, or that a plain dig would not have enough to go on.
argument-hint: "the question or topic to dig into"
allowed-tools: Bash(claude-bg-dispatch:*), Bash(claude agents:*), Bash(claude logs:*), Bash(mkdir:*), Bash(cp:*), Write, ListAgents
---

# Start a dig that inherits this conversation

Same mechanism as `dig`, one difference: this one is allowed to take its time,
because it hands over a written record of what happened here.

## Which one to use

The line is not fast versus thorough. It is **what the dispatched session could
find out by itself**:

- **Recoverable** — anything in a repo, a log, a commit history, a changelog, a
  web page. The session reads those on arrival, faster than you can for it, and
  in its own context. Never fetch these.
- **Unrecoverable** — what happened *in this conversation*: what we tried, what
  broke, the output we stared at, the reading we rejected and why, what David
  said he wanted. None of that is anywhere on disk once this session ends.

`dig` assumes there is nothing unrecoverable, which is right for a cold
question. Use this skill when there is, and when losing it would make the
dispatched session repeat work or reach a conclusion we already know is wrong.

If you are unsure, ask yourself whether a stranger reading only the repos would
reach the same starting point. If yes, use `dig`.

## How

**1. Write the context file.** Put it at `context.md` in your scratchpad
directory. This is the part worth spending time on:

- **The thread**: what this session was doing when the question came up, and why
  it came up. A dig that does not know why it exists tends to answer a
  neighbouring question.
- **What we tried**, with the actual commands and the actual output, verbatim
  where it is short. Paraphrased errors are much less useful than the error.
- **What we ruled out, and why.** This is the single most valuable part: it is
  what stops the session walking back into a dead end and reporting it as a
  finding.
- **Decisions and constraints** David stated, in his words where the wording
  carries the point.
- **Open questions** we did not resolve, marked as open rather than implied.
- **Exact coordinates**: paths, repos, branches, PR and issue numbers, versions,
  session ids, URLs.

Keep it evidence, not narrative. Nobody needs a story of the conversation; the
session needs what it would otherwise have to guess.

If there are bulky artifacts (a transcript, a log, a dump, a screenshot), write
them next to `context.md` as their own files and refer to them by name. A brief
cannot carry a file, only a path to one.

**Never put a secret in any of it.** The brief becomes process arguments and is
stored in `~/.claude/jobs/<id>/state.json`; the context file sits in a directory
the session can read. Name the secret and let the session fetch it with `fnox`.

**2. Still do not research the subject.** The time budget here is for writing
down what we know, not for going and learning more. If you catch yourself
reading the files the question is about, you are doing the dig in the wrong
session again; put the pointer in the context file instead.

**3. Write the brief**, short, pointing at the context file:

> <the question, stated so it stands alone>
>
> `context.md` in the directory added below is the record of the conversation
> this came out of: what was tried, what was ruled out, and the constraints that
> apply. Read it first, then **copy it into the dig directory as `context.md`**
> and cite it in the writeup, so the reasoning does not die with the session
> that produced it. Treat it as evidence of what happened, not as conclusions:
> verify anything load-bearing against the repos themselves.
>
> You are the top-level owner of this dig, not a helper. Follow the workbench's
> own instructions in full: start the dig, manage its worktree, commit as you go,
> and regenerate the index. Check `notes/` first for an existing dig on this
> subject; if there is one, this is a new angle on it, so use its slug and add a
> log entry rather than starting a second dig.
>
> Push and open a PR, then **stop there**. Do not merge, and do not run the
> shipping command that merges: David has not seen this work, and the PR is where
> you hand it to him.
>
> Nobody is watching this session. Do not ask questions and do not wait for an
> answer: take the sensible reading, say so in the writeup, and carry on. If you
> are truly blocked, stop and report rather than sitting idle.
>
> When you are done or blocked, call ListAgents, then SendMessage to the session
> named `<this session's name, from ListAgents>` with a two-line summary and the
> PR link. Do not wait for a reply. If no session is listed under that name, send
> a PushNotification instead.

**4. Dispatch it**, adding the directory holding `context.md`, plus the repo this
session is standing in and anything else the work needs to read:

```bash
claude-bg-dispatch --repo digs --name <slug> --brief <brief-file> \
  --add-dir <scratchpad-dir> --add-dir <repo-this-session-is-in>
```

The scratchpad is session-scoped, which is why the brief tells the session to
copy `context.md` into the dig: once it is committed there, the context outlives
both sessions, which is the whole point of the workbench.

**5. Report** the id with `claude logs <id>` / `claude attach <id>` / `claude
stop <id>`, say in one line what context you handed over, and carry on. Do not
poll it.
