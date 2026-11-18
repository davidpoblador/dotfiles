---
name: browser-automation
description: How to drive David's agent browser (Helium) with Browse, inspect it with the chrome-devtools CLI, or check WebKit with Safari. Use before the first browse MCP call in a task, before any chrome-devtools command, and when a task needs a web page opened, a logged-in site, a screenshot, a perf trace, network or console inspection, or a Safari check.
---

# Browser automation

The hard rules (which machine has Helium, which stack does what) are in the
global CLAUDE.md. This is how to use each stack.

## Browse (default)

[Browse](https://github.com/anomalyco/browse) drives Helium through its
extension: real tabs, David's logins (iCloud Passwords and passkeys work
there), and handoffs for login, 2FA or captchas. Its MCP server offers
`execute` (Playwright-style code; start each script from `await snapshot()`
and act on its refs), `status` and `tabs`. Tabs are the handle: every result
starts with `tab: <id>`, and passing that back keeps you in the same tab.

`browse status` names the browser `chrome-<host>` / "Chrome on <host>", where
`<host>` is the laptop's hostname, and Helium's user agent says Chrome. That
is Helium, not David's everyday Chrome (which has no Browse extension). Seeing
another machine's hostname there means you're on the agent host, going through
the tunnel, which is normal.

- For work that recurs, open a named tab (`tabs` action `new` with an `id`
  such as `bank-statements`, plus `keepOpen: true`): later runs get the same
  tab back without it being navigated. Without `keepOpen` it closes when idle
  like any other tab. A relay restart keeps it; a browser restart loses it, so
  the next open is a fresh tab.
- Give a tab an `allowedOrigins` list before reading untrusted content in it,
  naming only the sites the task needs. The list is fixed when the tab opens,
  so widening it means a new tab with the wider list, and only with David's
  OK. If the task starts with a login (handoff, "Continue with Google", SSO),
  log in from a tab without a list, then open the working tab with one: the
  login lives in the browser, not the tab. Sign-in flows hop through hosts
  nobody predicts (Google's goes via `accounts.youtube.com`), and a blocked hop
  strands the login on a page that won't load. Don't keep a standing list of
  identity provider hosts; it goes stale.
- A navigation the list refuses fails with "browse blocked ... has a domain
  allowlist", naming the host. Tell David which host it was.
- Work only in tabs you opened or David lent you. Close yours when done,
  except named tabs you mean to reuse.
- On the agent host, Browse's relay at `127.0.0.1:19988` is a reverse ssh
  tunnel to the laptop, so it works only while the laptop is awake. "no relay
  is running at 127.0.0.1:19988" there means stop and report, not retry,
  `browse serve` or `browse restart`.

## Chrome DevTools

For DevTools-grade work Browse doesn't cover, on the browser host only (the
agent host can't reach Helium's debug port; do that work from the laptop). Use
the `chrome-devtools` command; there is no MCP server for it. Run this `start`
at the beginning of every task, even if it ran before: another session may
have stopped the daemon, and a tool call with no daemon silently launches a
separate headless Chrome with a throwaway profile instead of attaching to
Helium.

```sh
chrome-devtools start --autoConnect "--userDataDir=$HOME/Library/Application Support/net.imput.helium" --usageStatistics=false --performanceCrux=false --redactNetworkHeaders --screenshotFormat=webp --screenshotMaxWidth=1280
```

Then run its tools as commands (`chrome-devtools list_pages`,
`chrome-devtools take_screenshot <page> --filePath out.webp`;
`chrome-devtools --help` lists them). The daemon is shared by every session on
the machine and attaches to the Helium Browse drives, so pages and state are
shared too. Run `chrome-devtools stop` when done. If `chrome-devtools status`
shows `args=["--viaCli"]` alone, it is that headless default: stop it and
start again with the command above.

## Safari

The `safari` MCP server (stock Safari's `safaridriver --mcp`) is not loaded by
default. When a task needs WebKit checks, on the browser host only, add it for
the project folder with the `claude mcp add-json -s local` command in
`TOOLS.md` of the dotfiles repo, then tell David it is available from the next
session in that folder (a running session doesn't pick it up).
