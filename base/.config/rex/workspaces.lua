-- ABOUTME: The Rex sessions each machine should always have, keyed by `hostname -s`.
-- ABOUTME: Rebuilt by workspaces-apply.lua whenever a server starts or reloads its config.
--
-- Each session: name, dir, optional dev command (a pane on the right), and
-- claude = false for a plain shell instead of `claude --continue || claude`.

return {
  lemon = {},
  tamarind = {
    { name = "digs", dir = "~/repos/digs" },
  },
}
