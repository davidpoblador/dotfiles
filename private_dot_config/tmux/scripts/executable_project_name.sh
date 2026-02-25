#!/bin/bash
dir="${1:-.}"
git_common_dir=$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null) || exit 0
if [ "$git_common_dir" = ".git" ]; then
  basename "$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)"
else
  basename "$(dirname "$git_common_dir")"
fi
