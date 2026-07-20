# TODO

## Starship prompt

- Add `cmd_duration` module (shows how long last command took, only above 2s threshold)
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

## After the next mise release (fixes merged upstream 2026-07-15/16)

- jdx/mise#11012 (Caskroom `.metadata` counted as a version): the spurious
  "multiple Caskroom versions found; reinstall to reconcile" warnings should
  disappear — confirm on the next `mise bootstrap --only packages` run.
- jdx/mise#10965 (launchd bootout EIO on first install): the one-time manual
  `launchctl bootstrap gui/$UID <plist>` workaround is no longer needed when
  adding new launchd agents.
- jdx/mise#11107 (cask shim `auto_updates` support, still open): once merged,
  try moving docker-desktop and vlc from the bootstrap-task brew fallback back
  to `[bootstrap.packages]` as `brew-cask:` entries.
- ngrok (`postflight_steps` unsupported) and raycast ("app artifact not
  found") were not covered by the above: recheck after the shim rework lands
  and file a combined cask-shim coverage discussion if they still reproduce.
- systemd timer `unit` naming discussion (filed from this repo): if mise
  starts normalizing bare unit names, simplify
  `unit = "dev.mise.dotfiles-maintain.service"` back to the entry name.
