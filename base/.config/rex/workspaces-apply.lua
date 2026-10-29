-- ABOUTME: Creates the Rex sessions declared in a workspaces file, on this server and on remote hosts.
-- ABOUTME: Missing sessions are created; live ones are left alone apart from restoring a drifted name.
--
-- Usage: rex do workspaces-apply.lua [config=PATH] [host=LABEL] [dry_run=true]

local HOME = os.getenv("HOME")
local SHELL_FLAVOR = "com.superlogical.terminal.shell"

local args = rex.args or {}
local config_path = args.config or (HOME .. "/.config/rex/workspaces.lua")
local only_host = args.host
local dry_run = args.dry_run == true

local function expand(path)
  return (path:gsub("^~", HOME))
end

local function local_hostname()
  local r, err = rex.exec{ "hostname", "-s" }
  if r == nil then error(err, 0) end
  return (r.stdout:gsub("%s+$", ""))
end

-- Runs a program in an interactive shell and keeps the shell when it exits,
-- so quitting the program leaves a prompt in the same directory.
local function pane_command(line)
  return { "zsh", "-ic", line .. "; exec zsh -i" }
end

local function pane(dir, line)
  local options = { cwd = dir }
  if line ~= nil then options.command = pane_command(line) end
  return { block = { flavor = SHELL_FLAVOR, options = options } }
end

local function session_layout(spec)
  local dir = expand(spec.dir)
  local main = pane(dir, spec.claude ~= false and "claude --continue || claude" or nil)
  if spec.dev == nil then return main end
  return {
    split = {
      direction = "horizontal",
      ratio     = 0.5,
      before    = main,
      after     = pane(dir, spec.dev),
    },
  }
end

local function must(result, err)
  if result == nil then error(err, 0) end
  return result
end

-- Every directory a session's panes are working in, read from each pane's
-- foreground process.
local function session_dirs(api, session_id)
  must(api.call("session.attach", { session_id = session_id }))
  local blocks = must(api.call("session.list_blocks", { session_id = session_id }))
  local dirs = {}
  for _, b in ipairs(blocks.blocks or {}) do
    local p = api.call("block.method", {
      session_id = session_id,
      block_id   = b.block_id,
      method     = "process",
    })
    local fg = p and p.foreground
    if fg ~= nil and fg.cwd ~= nil then table.insert(dirs, fg.cwd) end
  end
  return dirs
end

local function within(path, dir)
  return path == dir or path:sub(1, #dir + 1) == dir .. "/"
end

local function any_within(dirs, dir)
  for _, d in ipairs(dirs) do
    if within(d, dir) then return true end
  end
  return false
end

local function all_within(dirs, dir)
  for _, d in ipairs(dirs) do
    if not within(d, dir) then return false end
  end
  return #dirs > 0
end

-- Decides what to do for one declared session:
--   exists:  a live session has its name;
--   renamed: one live session works only in its directory under another name
--            (Claude renames sessions after its first task);
--   in_use:  its directory is busy in a session shared with other projects,
--            so creating it would start a second Claude on the same
--            conversation;
--   created: nothing on the host is working in its directory.
local function plan(sessions, dirs_of, spec, claimed)
  for _, s in ipairs(sessions) do
    if s.label == spec.name and not claimed[s.session_id] then
      return "exists", s
    end
  end
  local dir = expand(spec.dir)
  local users = {}
  for _, s in ipairs(sessions) do
    if not claimed[s.session_id] and any_within(dirs_of[s.session_id], dir) then
      table.insert(users, s)
    end
  end
  if #users == 0 then return "created" end
  if #users == 1 and all_within(dirs_of[users[1].session_id], dir) then
    return "renamed", users[1]
  end
  return "in_use", users[1]
end

local function apply_host(label, api, specs)
  local report = {}
  local sessions = must(api.call("session.list", {})).sessions or {}
  local dirs_of = {}
  for _, s in ipairs(sessions) do dirs_of[s.session_id] = session_dirs(api, s.session_id) end
  local claimed = {}
  for _, spec in ipairs(specs) do
    local action, found = plan(sessions, dirs_of, spec, claimed)
    if found ~= nil and action ~= "in_use" then claimed[found.session_id] = true end
    if action == "exists" then
      table.insert(report, { session = spec.name, action = action })
    elseif action == "renamed" then
      if not dry_run then
        must(api.call("session.set_label", { session_id = found.session_id, label = spec.name }))
      end
      table.insert(report, { session = spec.name, action = action, from = found.label })
    elseif action == "in_use" then
      table.insert(report, { session = spec.name, action = action, by = found.label })
    else
      if not dry_run then
        must(api.call("session.create", {
          label           = spec.name,
          initial_windows = { { window_label = spec.name, layout = session_layout(spec) } },
        }))
      end
      table.insert(report, { session = spec.name, action = "created" })
    end
  end
  return report
end

local config = dofile(expand(config_path))
local here = local_hostname()
local result = { dry_run = dry_run }

for label, specs in pairs(config) do
  if only_host == nil or only_host == label then
    local api
    if label == here then api = rex else api = rex.server(label) end
    result[label] = apply_host(label, api, specs)
  end
end

return result
