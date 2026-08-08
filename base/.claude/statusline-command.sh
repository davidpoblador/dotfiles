#!/bin/bash
# ABOUTME: Claude Code statusline: renders the session label, cwd, model,
# ABOUTME: context %, cost, quota and git state from the JSON piped on stdin.

input=$(cat)

# ── Extract JSON fields (single jq: this re-renders constantly) ──────
# Read line-per-value rather than tab-splitting: tab is an IFS whitespace
# character, so a `read` on tabs collapses empty fields and shifts every
# value after an absent one.
f=()
while IFS= read -r line; do
    f[${#f[@]}]="$line"
done < <(
  echo "$input" | jq -r '[.workspace.current_dir, .workspace.project_dir,
    (.workspace.repo.name // ""),
    .model.display_name, (.effort.level // ""), (.fast_mode // false),
    (.context_window.used_percentage // 0 | floor),
    (.cost.total_cost_usd // 0), (.cost.total_duration_ms // 0),
    (.cost.total_lines_added // 0), (.cost.total_lines_removed // 0),
    (.agent.name // ""), (.session_name // ""),
    (.worktree.name // ""), (.worktree.branch // ""), (.worktree.original_cwd // ""),
    (.pr.number // ""), (.pr.review_state // ""),
    (.rate_limits.five_hour.used_percentage // -1 | floor),
    (.rate_limits.seven_day.used_percentage // -1 | floor)] | .[]'
)

cwd=${f[0]};        project_dir=${f[1]};  repo_name=${f[2]}
model=${f[3]};      effort=${f[4]};       fast_mode=${f[5]}
pct=${f[6]};        cost=${f[7]};         duration_ms=${f[8]}
lines_add=${f[9]};  lines_rm=${f[10]};    agent_name=${f[11]}
session_name=${f[12]}
wt_name=${f[13]};   wt_branch=${f[14]};   wt_origin=${f[15]}
pr_num=${f[16]};    pr_state=${f[17]}
rl5=${f[18]};       rl7=${f[19]}

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

# Colour for a 0-100 percentage where higher is worse.
heat() {
    if [ "$1" -ge 90 ]; then printf '%s' "$fg_red"
    elif [ "$1" -ge 70 ]; then printf '%s' "$fg_yellow"
    elif [ "$1" -ge 40 ]; then printf '%s' "$fg_aqua"
    else printf '%s' "$fg_green"; fi
}

# ── Git info ─────────────────────────────────────────────────────────
# The harness supplies worktree identity, so git is consulted only for the
# branch outside a worktree and for the dirty counts.
git_branch="$wt_branch"
git_dirty=""

if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    if [ -z "$git_branch" ]; then
        git_branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
        [ -z "$git_branch" ] && git_branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    fi

    # One porcelain call rather than two numstat calls.
    staged=0
    modified=0
    while IFS= read -r st; do
        [ -n "$st" ] || continue
        x=${st:0:1}
        y=${st:1:1}
        case "$x" in
            '?'|' ') ;;
            *) staged=$((staged + 1)) ;;
        esac
        case "$y" in
            ' '|'') ;;
            '?') ;;
            *) modified=$((modified + 1)) ;;
        esac
    done < <(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)

    [ "$staged" -gt 0 ] && git_dirty="${fg_green}+${staged}${reset}"
    [ "$modified" -gt 0 ] && git_dirty="${git_dirty}${fg_yellow}~${modified}${reset}"
fi

# ── Project name ─────────────────────────────────────────────────────
# In a worktree the harness names the originating checkout, so the real
# project no longer has to be derived from git's common dir.
if [ -n "$repo_name" ]; then
    display_project="$repo_name"
elif [ -n "$wt_origin" ]; then
    display_project=$(basename "$wt_origin")
else
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
bar_color=$(heat "$pct")

bar=""
[ "$filled" -gt 0 ] && bar=$(printf "%${filled}s" | tr ' ' '█')
[ "$empty" -gt 0 ] && bar="${bar}${fg_gray}$(printf "%${empty}s" | tr ' ' '░')${reset}"

# ── LINE 1: Model + Project + Branch + Worktree + PR + Agent ─────────
hostname=$(hostname -s)
case "$(uname)" in
    Darwin) os_emoji="🍎" ;;
    Linux)  os_emoji="🐧" ;;
    *)      os_emoji="🖥️" ;;
esac

model_label="$model"
[ -n "$effort" ] && model_label="${model_label} ${effort}"
[ "$fast_mode" = "true" ] && model_label="${model_label} ⚡"

line1="🤖 ${fg_orange}${bold}${model_label}${reset}"
line1="${line1}${sep}${os_emoji} ${fg_gray}${hostname}${reset}"
line1="${line1}${sep}📁 ${fg_white}${display_project}${reset}"

if [ -n "$git_branch" ]; then
    line1="${line1}${sep}🌿 ${fg_aqua}${git_branch}${reset}"
    [ -n "$git_dirty" ] && line1="${line1} ${git_dirty}"
fi

[ -n "$wt_name" ] && line1="${line1}${sep}🌳 ${fg_purple}${wt_name}${reset}"

if [ -n "$pr_num" ]; then
    case "$pr_state" in
        approved)          pr_color="$fg_green" ;;
        changes_requested) pr_color="$fg_red" ;;
        *)                 pr_color="$fg_gray" ;;
    esac
    line1="${line1}${sep}⇧ ${pr_color}#${pr_num}${reset}"
fi

[ -n "$agent_name" ] && line1="${line1}${sep}🕵️ ${fg_purple}${agent_name}${reset}"

# ── LINE 0: Session label, only once one exists ──────────────────────
# Absent until the session is named with --name or /rename, or picks up an
# AI-generated title; the default handle (my-app-3f) does not populate it.
line0=""
[ -n "$session_name" ] && line0="🏷️ ${fg_white}${bold}${session_name}${reset}"

# ── LINE 2: Context bar + Cost + Duration + Lines + Quota ────────────
cost_fmt=$(printf '$%.2f' "$cost")

line2="🧠 ${bar_color}${bar}${reset} ${fg_gray}${pct}%${reset}"
line2="${line2}${sep}💰 ${fg_yellow}${cost_fmt}${reset}"
line2="${line2}${sep}⏱️ ${fg_gray}${duration_fmt}${reset}"

if [ "$lines_add" -gt 0 ] || [ "$lines_rm" -gt 0 ]; then
    line2="${line2}${sep}✏️ ${fg_green}+${lines_add}${reset} ${fg_red}-${lines_rm}${reset}"
fi

# Plan quota: five-hour window, then the weekly one.
if [ "$rl5" -ge 0 ]; then
    line2="${line2}${sep}⏳ $(heat "$rl5")${rl5}%${reset}"
    [ "$rl7" -ge 0 ] && line2="${line2}${fg_gray}/${reset}$(heat "$rl7")${rl7}%${reset}"
fi

# ── Output ───────────────────────────────────────────────────────────
[ -n "$line0" ] && printf '%b\n' "$line0"
printf '%b\n' "$line1"
printf '%b\n' "$line2"
