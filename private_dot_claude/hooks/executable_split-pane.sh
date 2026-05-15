#!/usr/bin/env bash
# ABOUTME: Opens a Ghostty split-right at the given (or current) cwd via AppleScript.
# ABOUTME: Backs the `:t` magic prompt hook; also usable standalone (`split-pane [dir]`).
set -euo pipefail

CWD="${1:-$PWD}"

osascript - "$CWD" >/dev/null <<'EOF'
on run argv
  set cwd to item 1 of argv
  tell application "Ghostty"
    split (focused terminal of selected tab of front window) direction right with configuration {initial working directory:cwd}
  end tell
end run
EOF
