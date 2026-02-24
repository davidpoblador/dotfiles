#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# ── Extract JSON fields ──────────────────────────────────────────────
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir')
model=$(echo "$input" | jq -r '.model.display_name')
pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
lines_add=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_rm=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
agent_name=$(echo "$input" | jq -r '.agent.name // empty')

# ── Colors (Gruvbox-inspired) ────────────────────────────────────────
bold='\033[1m'
reset='\033[0m'
fg_orange='\033[38;5;208m'
fg_aqua='\033[38;5;109m'
fg_green='\033[38;5;142m'
fg_yellow='\033[38;5;214m'
fg_red='\033[38;5;167m'
fg_purple='\033[38;5;175m'
fg_gray='\033[38;5;245m'
fg_white='\033[38;5;223m'

sep=" "

# ── Git info ─────────────────────────────────────────────────────────
git_branch=""
git_dirty=""
is_worktree=""
worktree_name=""
real_project=""

if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    git_branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
    [ -z "$git_branch" ] && git_branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)

    # Dirty state
    staged=$(git -C "$cwd" --no-optional-locks diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
    modified=$(git -C "$cwd" --no-optional-locks diff --numstat 2>/dev/null | wc -l | tr -d ' ')
    [ "$staged" -gt 0 ] && git_dirty="${fg_green}+${staged}${reset}"
    [ "$modified" -gt 0 ] && git_dirty="${git_dirty}${fg_yellow}~${modified}${reset}"

    # Worktree detection — derive real project name from the main repo
    git_dir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null)
    git_common=$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null)
    if [ "$git_dir" != "$git_common" ] 2>/dev/null; then
        is_worktree="yes"
        worktree_name=$(basename "$cwd")
        # git_common is like /path/to/real-repo/.git — go up one level
        real_project=$(basename "$(dirname "$(cd "$cwd" && realpath "$git_common")")")
    fi
fi

# ── Project name ─────────────────────────────────────────────────────
if [ -n "$is_worktree" ] && [ -n "$real_project" ]; then
    # In a worktree: show the real project name
    display_project="$real_project"
else
    # Normal: just the project dir basename
    display_project=$(basename "$project_dir")
fi

# ── Duration formatting ──────────────────────────────────────────────
duration_sec=$((duration_ms / 1000))
if [ "$duration_sec" -ge 3600 ]; then
    hrs=$((duration_sec / 3600))
    mins=$(((duration_sec % 3600) / 60))
    duration_fmt="${hrs}h${mins}m"
elif [ "$duration_sec" -ge 60 ]; then
    mins=$((duration_sec / 60))
    secs=$((duration_sec % 60))
    duration_fmt="${mins}m${secs}s"
else
    duration_fmt="${duration_sec}s"
fi

# ── Context bar (color-coded) ────────────────────────────────────────
bar_width=8
filled=$((pct * bar_width / 100))
empty=$((bar_width - filled))

if [ "$pct" -ge 90 ]; then
    bar_color="$fg_red"
elif [ "$pct" -ge 70 ]; then
    bar_color="$fg_yellow"
elif [ "$pct" -ge 40 ]; then
    bar_color="$fg_aqua"
else
    bar_color="$fg_green"
fi

bar=""
[ "$filled" -gt 0 ] && bar=$(printf "%${filled}s" | tr ' ' '█')
[ "$empty" -gt 0 ] && bar="${bar}${fg_gray}$(printf "%${empty}s" | tr ' ' '░')${reset}"

# ── LINE 1: Model + Project + Branch + Worktree + Agent ──────────────
# Hostname with OS-appropriate emoji
hostname=$(hostname -s)
case "$(uname)" in
    Darwin) os_emoji="🍎" ;;
    Linux)  os_emoji="🐧" ;;
    *)      os_emoji="🖥️" ;;
esac

line1="🤖 ${fg_orange}${bold}${model}${reset}"
line1="${line1}${sep}${os_emoji} ${fg_gray}${hostname}${reset}"
line1="${line1}${sep}📁 ${fg_white}${display_project}${reset}"

if [ -n "$git_branch" ]; then
    line1="${line1}${sep}🌿 ${fg_aqua}${git_branch}${reset}"
    [ -n "$git_dirty" ] && line1="${line1} ${git_dirty}"
fi

if [ -n "$is_worktree" ]; then
    line1="${line1}${sep}🌳 ${fg_purple}${worktree_name}${reset}"
fi

if [ -n "$agent_name" ]; then
    line1="${line1}${sep}🕵️ ${fg_purple}${agent_name}${reset}"
fi

# ── LINE 2: Context bar + Cost + Duration + Lines ────────────────────
cost_fmt=$(printf '$%.2f' "$cost")

line2="🧠 ${bar_color}${bar}${reset} ${fg_gray}${pct}%${reset}"
line2="${line2}${sep}💰 ${fg_yellow}${cost_fmt}${reset}"
line2="${line2}${sep}⏱️ ${fg_gray}${duration_fmt}${reset}"

if [ "$lines_add" -gt 0 ] || [ "$lines_rm" -gt 0 ]; then
    line2="${line2}${sep}✏️ ${fg_green}+${lines_add}${reset} ${fg_red}-${lines_rm}${reset}"
fi

# ── Output ───────────────────────────────────────────────────────────
printf '%b\n' "$line1"
printf '%b\n' "$line2"
