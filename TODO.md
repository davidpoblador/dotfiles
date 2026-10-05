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

## Migration leftovers

- Optionally fold `expose.env` into fnox and drop the `EXPOSE_CONFIG`
  special case in `.zshenv`
- durian has no `~/sync`, so its `~/.config/alltuner` symlink and
  `EXPOSE_CONFIG` dangle; fix only if those are actually used there
