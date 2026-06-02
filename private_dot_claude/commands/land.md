---
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git branch:*), Bash(git switch:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(git merge:*), Bash(git log:*), Bash(git worktree:*), Bash(grep:*), ExitWorktree
description: Commit and fast-forward the change straight onto main, no PR, then clean up the worktree
---

## Context

- This repo is PUBLIC: never commit secrets (`sk-`, `ghp_`, `gho_`, `AKIA`, `Bearer`, passwords, private hostnames/IPs, SSH keys, `.env` contents).
- Git status: !`git status`
- Diff (staged + unstaged): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Worktrees: !`git worktree list`

## Your task

Land these changes directly on the default branch without opening a PR. Use this only for trivial solo changes that don't need review — reach for `/ship` when you want the PR trail or a second pair of eyes.

1. Scan the diff for secrets (see the patterns above). If anything matches, STOP and report it instead of committing.
2. Create ONE commit on the current branch with a lowercase, imperative, concise subject. End the message with the trailer:
   `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
3. Identify the main working tree (first entry of `git worktree list`) and its default branch.
4. Fast-forward the default branch onto this commit and push, operating on the main checkout so you don't disturb the session's cwd yet:
   - `git -C <main> switch <default>`
   - `git -C <main> merge --ff-only <this-branch>`
   - `git -C <main> push origin <default>`
   - If the fast-forward is rejected because the default branch moved, STOP and tell David — rebase is his call, don't force it.
5. Return the session to the main checkout and remove this worktree: if this session created it (via EnterWorktree), call `ExitWorktree` with action `remove` (the commit is now the default-branch tip, so it removes cleanly). Otherwise switch to the main working tree and delete the merged branch yourself.
6. Report the new default-branch tip.
