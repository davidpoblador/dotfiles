---
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git branch:*), Bash(git switch:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(git pull:*), Bash(git fetch:*), Bash(git rebase:*), Bash(git log:*), Bash(git show:*), Bash(git checkout -- :*), Bash(git worktree:*), Bash(git symbolic-ref:*), Bash(gh pr create:*), Bash(gh pr merge:*), Bash(gh pr view:*), Bash(gh repo view:*), Bash(grep:*), ExitWorktree
description: Commit, push, open a PR, squash-merge it, then return to an updated main checkout
---

## Context

- Git status: !`git status`
- Diff (staged + unstaged): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Default branch: !`git symbolic-ref --short refs/remotes/origin/HEAD`
- Worktrees: !`git worktree list`

## Your task

Take the work on this branch all the way to a merged, cleaned-up state.

1. Scan the diff for secrets (`sk-`, `ghp_`, `gho_`, `AKIA`, `Bearer`, passwords, private hostnames/IPs, SSH keys, `.env` contents). If anything matches, stop and report it instead of committing. Take extra care when `gh repo view --json visibility` says the repo is public.
2. If on the default branch, create a feature branch first.
3. Commit any uncommitted changes. Follow the repo's own commit-message conventions when its instructions define them; otherwise use a concise, lowercase, imperative subject.
4. `git fetch origin` and rebase onto the fresh default-branch tip, unless the branch has already been pushed and reviewed (then ask David first).
5. Work out the remote branch name. With `B` = current branch, run `R=${B#worktree-}; R=${R//+//}` (bash or zsh). The worktree tool names local branches `worktree-<name>` and writes a `/` in the name as `+`, so this turns `worktree-dig+foo` into `dig/foo`. For other branches it leaves the name unchanged. Push with `git push -u origin HEAD:$R`.
6. Open the PR with `gh pr create --head "$R"`, using the commit subject as the title and a body that summarizes the change. Without `--head`, `gh` infers the local branch name, which has no remote counterpart.
7. Squash-merge with `gh pr merge --squash`. Never pass `--delete-branch`: from a worktree it fails trying to check out the default branch, which the main worktree holds. GitHub's auto-delete removes the remote branch.
8. Return the session to an up-to-date main checkout:
   - If this session created the worktree (EnterWorktree), confirm with `gh pr view` that the PR is `MERGED` and the tree is clean. Then call `ExitWorktree` with action `remove` and `discard_changes: true`. Squash merges look unmerged by ancestry, so the first attempt without it is refused.
   - Otherwise switch the session to the main working tree (first entry of `git worktree list`).
   - Check `git worktree list`. If the worktree is still there, finish with `git worktree remove <path> && git branch -D <local-branch>`.
   - In the main checkout, `git switch <default> && git pull --ff-only`. If files this PR changed show as uncommitted reversions, run `git checkout -- <paths>` on exactly those files (`git show --name-only <merge-sha>`) and leave every other uncommitted path alone.
9. Report the PR URL and confirm the main checkout is at the merged tip.
