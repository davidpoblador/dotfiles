# TODO

## Starship prompt

- Add `cmd_duration` module to starship-dev.toml (prod already has it)
- Add `jobs` module (shows background job count)
- Add `zig` language module (already in mise, missing from prompt)

## Atuin

- Try enabling sync (self-hosted or atuin.sh) for cross-machine history
  (config is explicitly local-only today; see the comment in atuin/config.toml)

## Bat

- Configure as MANPAGER for syntax-highlighted man pages
  (theme is already set in `~/.config/bat/config`)

## Background sessions

- `digs <topic>` sends no brief, so a terminal-launched session carries none of
  the guards the skills add: nothing stops it merging its own PR, and nothing
  tells it to assume rather than ask. Putting the stop-at-the-PR rule in the
  workbench's own instructions would cover both paths with one copy, which is
  better than giving the shell function a preamble that would then drift from
  the skills.

## Auto-compact trial

`autoCompactWindow: 500000` in `base/.claude/settings.json` is a trial, from the
digs dig `agent-session-friction`. Judge it a week after it is applied:

- Rerun the dig's scripts from a digs worktree, with the window starting on the
  day dotfiles PR #233 was merged and pulled (`gh pr view 233`):
  `notes/agent-session-friction/regen.sh <that date>`. Settings load at session
  start, so sessions already open that day still compact at the old window;
  leave them out (`regen.sh` takes session ids to exclude). It overwrites the
  dig's committed `data/`, so record the results in the dig's Log rather than
  committing over the baseline.
- The share of requests at 500k or more (baseline 16% of requests, 40% of
  cache reads) and sessions peaking above 500k (39 of 196) fall to about zero
  by construction. They only confirm the setting took effect.
- Judge it on what can go either way, against the dig's 14-day baseline:
  - cache-read tokens per request: 10.7B over 38,045, about 281k;
  - model time per tool call: median 5.0 s, mean 7.4 s, overall rather than per
    band;
  - net time: compactions will rise (baseline 26 runs in 17 sessions, 34 min).
    The dig estimates the 500k+ band cost 3 to 4 h of model time per 14 days.
    Added compaction minutes plus re-orientation after each one (read a few:
    re-reads, repeated searches) must stay well below that, or revert;
  - per project, since digs is 147 of 254 sessions and a shift in the mix can
    move the totals.
- It is a before/after, not an A/B, and `enableArtifact: false` and the plugin
  trims landed in the same days (about 13k tokens off every request). Rerun
  `overhead.py` to check how much of the drop is theirs.
- Don't run `/autocompact` while it runs: it saves a per-model value under
  `modelSettings` in the same tracked file, which overrides this key.
- One session can opt out with `claude --autocompact auto` (the model's tuned
  window). Reverting is deleting the line.

## Migration leftovers

- Optionally fold `expose.env` into fnox and drop the `EXPOSE_CONFIG`
  special case in `.zshenv`
- durian has no `~/sync`, so its `~/.config/alltuner` symlink and
  `EXPOSE_CONFIG` dangle; fix only if those are actually used there
