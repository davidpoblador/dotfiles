-- ABOUTME: Rex configuration shared by every machine.
-- ABOUTME: On each load (server start or reload) it rebuilds this machine's sessions from workspaces.lua.

local HOME = os.getenv("HOME")

-- The rex CLI bundled with the server: the same path on every Mac, and not
-- always on PATH.
local REX = HOME .. "/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex"

-- The config can't call the session API while it loads, so a detached
-- `rex do` applies the sessions once the server answers.
local apply = [[
exec >>"$HOME/Library/Logs/rex-workspaces.log" 2>&1
date
for _ in $(seq 30); do "$0" --autostart=false ls >/dev/null 2>&1 && break; sleep 1; done
exec "$0" --autostart=false do "$HOME/.config/rex/workspaces-apply.lua" host="$(hostname -s)"
]]

rex.exec.start({ "/bin/sh", "-c", apply, REX }, {
  detach = true,
  stdout = false,
  stderr = false,
})
