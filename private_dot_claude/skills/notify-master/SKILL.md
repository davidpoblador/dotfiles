---
name: notify-master
description: Send a Telegram notification to David (the user) when he asks to be notified, pinged, or messaged about task completion or results. Triggers on phrases like "notify your master when you have an answer", "notify me when done", "ping me when X is ready", "let me know when X is fixed".
---

# notify-master

Sends a Telegram message to David via the `notify-master` shell command.

## When to use

Invoke this skill only when David explicitly asks to be notified, pinged, texted, or messaged about a task's completion or an answer. Do not ping him on every turn — only when he asks for it.

## How to use

Run:

    notify-master "<message>"

The message is a single argument. Write something short and specific that delivers the answer or summary inline — David should not need to switch back to the session to see what happened. For longer findings, include the key conclusion in the ping and note where the full details live (e.g. "see session for the diff").

The script automatically prepends the short hostname as `[<host>] ` so David can tell which machine pinged him. Do not add the hostname yourself.

## Handling failures

The command exits non-zero if Telegram credentials are missing or the API call fails. Its stderr explains what went wrong (missing env file, empty token, network failure, Telegram rejected the request, etc.).

On failure:

1. Tell David in-session that the notification did not go through.
2. Include the stderr from `notify-master` so he can fix the setup.
3. Deliver the answer in-session as usual.
