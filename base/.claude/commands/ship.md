---
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git branch:*), Bash(git switch:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(git pull:*), Bash(git fetch:*), Bash(git log:*), Bash(git worktree:*), Bash(gh pr create:*), Bash(gh pr merge:*), Bash(gh pr view:*), Bash(grep:*), ExitWorktree
description: Commit, push, open a PR, squash-merge it, then return to an updated main checkout
---

## Context

- This repo is PUBLIC: never commit secrets (`sk-`, `ghp_`, `gho_`, `AKIA`, `Bearer`, passwords, private hostnames/IPs, SSH keys, `.env` contents).
- Git status: !`git status`
- Diff (staged + unstaged): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Worktrees: !`git worktree list`

## Your task

Take the changes above all the way to a merged, cleaned-up state. Do not stop partway.

1. Scan the diff for secrets (see the patterns above). If anything matches, STOP and report it instead of committing.
2. If on the default branch, create a feature branch first. Otherwise use the current branch.
3. Create ONE commit with a lowercase, imperative, concise subject. End the message with the trailer:
   `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
4. Push the branch. EnterWorktree creates the local branch with a `worktree-` prefix that must NOT reach the remote, so push to the de-prefixed name: with `B` = current branch, the remote name is `${B#worktree-}`. Push with the explicit refspec `git push -u origin HEAD:${B#worktree-}` (for a non-worktree branch the two names are identical, so this is always correct).
5. Open a PR with `gh pr create --head ${B#worktree-}` — title from the commit subject, body summarizing the change. The `--head` is required: without it `gh` infers the prefixed local branch, which has no remote counterpart, and errors.
6. Squash-merge it: `gh pr merge --squash`. NEVER pass `--delete-branch` from a worktree (it fails trying to checkout the default branch that the main worktree already holds).
7. Return the session to the main checkout and bring it up to date:
   - If this session created the current worktree (via EnterWorktree), call `ExitWorktree` with action `remove`. Squash-merge leaves the local branch looking unmerged by ancestry, so after confirming the working tree is clean and the change is on `origin/<default>`, pass `discard_changes: true`.
   - Otherwise, switch the session to the main working tree (first entry of `git worktree list`) yourself.
   - In the main checkout: `git switch <default> && git pull --ff-only`.
8. Report the PR number/URL and confirm the main checkout is at the merged tip.
