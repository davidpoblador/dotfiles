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

## Migration leftovers

- Optionally fold `expose.env` into fnox and drop the `EXPOSE_CONFIG`
  special case in `.zshenv`
- durian has no `~/sync`, so its `~/.config/alltuner` symlink and
  `EXPOSE_CONFIG` dangle; fix only if those are actually used there
