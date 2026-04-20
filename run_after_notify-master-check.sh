#!/bin/bash
# Warn on chezmoi apply if the notify-master Telegram credentials are not
# configured. Non-blocking — the notify-master script itself fails gracefully
# with a clear error. This just surfaces the setup step so it isn't forgotten
# on fresh machines.

set -euo pipefail

ENV_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/notify-master/env"

if [[ -f "$ENV_FILE" ]]; then
  exit 0
fi

cat <<EOF
[notify-master] Telegram credentials not configured.
  Copy ~/.config/notify-master/env.example to ~/.config/notify-master/env
  and fill in TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID to enable Telegram
  notifications from agents. Until then, \`notify-master\` exits non-zero
  and agents will report that the ping did not go through.
EOF
