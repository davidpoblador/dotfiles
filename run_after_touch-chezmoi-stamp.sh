#!/bin/bash
# Record when chezmoi last applied, used by .zlogin to remind about updates.
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}"
touch "${XDG_CACHE_HOME:-$HOME/.cache}/chezmoi_last_apply"
