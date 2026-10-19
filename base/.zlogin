# Show branding on login (after system MOTD)
if [[ -o login && -o interactive ]]; then
  # The All Tuner mark in sextant blocks, 16 columns wide.
  local -a logo_lines
  logo_lines=(
    '    🬞🬭🬹🬹🬹🬹🬭🬏'
    '  🬵🬻█🬂███🬕🬂█🬺🬱'
    ' 🬷███🬹███▌ ███🬲'
    '🬦████ ████🬎████🬓'
    '🬉████ █🬝🬬▌ ████🬄'
    ' 🬨███🬱🬁🬀🬂🬟🬷███🬕'
    '  🬊🬬███🬓▐███🬝🬆'
    '    🬂🬊🬎🬄🬉🬎🬆🬂'
  )
  local logo_width=16 gutter=3
  local mark_png="$HOME/.local/share/alltuner/mark.png"

  # True when the terminal answers the graphics-protocol query. The device
  # attributes request rides along so a terminal that ignores the first one
  # still ends the read.
  _has_graphics() {
    [[ -t 0 && -t 1 && -r $mark_png ]] || return 1
    local saved reply="" c
    saved=$(stty -g 2>/dev/null) || return 1
    stty -echo raw 2>/dev/null
    print -n $'\033_Gi=1,s=1,v=1,a=q,t=d,f=24;AAAA\033\\\033[c'
    while read -t 0.4 -k 1 c; do
      reply+=$c
      [[ $c == c ]] && break
    done
    stty "$saved" 2>/dev/null
    [[ $reply == *$'\033'_Gi=1\;OK* ]]
  }

  # Place the mark in a logo_width x logo_rows cell box, leaving the cursor put.
  # Payloads go out in 4096-byte chunks, which is the protocol's limit.
  _draw_mark() {
    local ctl="a=T,f=100,c=${logo_width},r=${#logo_lines},q=2,C=1"
    local data=$(base64 < "$mark_png" | tr -d '\n')
    while (( ${#data} > 4096 )); do
      print -n "\033_G${ctl},m=1;${data[1,4096]}\033\\"
      data=${data[4097,-1]}
      ctl="q=2"
    done
    print -n "\033_G${ctl},m=0;${data}\033\\"
  }

  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"

  zmodload zsh/datetime zsh/stat

  # Format a file's mtime as "X min ago" / "X h ago" / "yesterday" / "N days ago".
  # Sets reply=(msg seconds). seconds is -1 when the file is missing.
  _relative_time() {
    local file="$1" mtime secs msg
    local -a stat_out
    if ! zstat -A stat_out +mtime "$file" 2>/dev/null; then
      reply=("never" -1)
      return
    fi
    mtime=$stat_out[1]
    secs=$(( EPOCHSECONDS - mtime ))
    if (( secs < 60 )); then
      msg="just now"
    elif (( secs < 3600 )); then
      msg="$((secs / 60))min ago"
    elif (( secs < 86400 )); then
      msg="$((secs / 3600))h ago"
    elif (( secs < 172800 )); then
      msg="yesterday"
    else
      msg="$((secs / 86400)) days ago"
    fi
    reply=("$msg" $secs)
  }

  local sync_msg sync_secs brew_msg brew_secs
  _relative_time "$cache_dir/dotfiles_last_apply"
  sync_msg="$reply[1]"; sync_secs=$reply[2]

  _relative_time "$cache_dir/brew_last_update"
  brew_msg="$reply[1]"; brew_secs=$reply[2]

  # System info
  local users_count=$(who | wc -l | tr -d ' ')
  local uptime_str
  if [[ "$OSTYPE" == darwin* ]]; then
    local up boot days hours mins
    boot=$(sysctl -n kern.boottime 2>/dev/null)
    boot=${boot#*sec = }
    boot=${boot%%,*}
    up=$(( EPOCHSECONDS - boot ))
    days=$(( up / 86400 ))
    hours=$(( (up % 86400) / 3600 ))
    mins=$(( (up % 3600) / 60 ))
    if (( days > 0 )); then
      uptime_str="$days days, ${(l:2::0:)hours}:${(l:2::0:)mins}"
    else
      uptime_str="${(l:2::0:)hours}:${(l:2::0:)mins}"
    fi
  else
    uptime_str=$(uptime -p | sed 's/^up //')
  fi
  local disk_usage=$(df -h / 2>/dev/null | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')
  local mem_usage
  if command -v free &>/dev/null; then
    mem_usage=$(free -h | awk '/^Mem:/ {print $3 "/" $2}')
  else
    local total=$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.0fG", $1/1073741824}')
    local used=$(vm_stat 2>/dev/null | awk '
      /page size of/ { pagesize = $(NF-1) }
      /^Pages active|^Pages wired|^Pages occupied by compressor/ {
        gsub(/\./, "", $NF); pages += $NF
      }
      END { printf "%.1fG", pages * pagesize / 1073741824 }
    ')
    mem_usage="${used} / ${total}"
  fi

  # Yellow marks a staleness of a week or more, or a stamp that never existed.
  _stale_color() {
    [[ $1 -ge 604800 || $1 -eq -1 ]] && print -n $'\033[33m'
  }

  # Each info row is "label\tcolor\tvalue"; labels are dimmed and right-aligned.
  local -a info_rows
  info_rows=(
    $'Host\t\t'"${HOST%%.*}"
    $'Uptime\t\t'"$uptime_str"
    $'Sessions\t\t'"$users_count"
    $'Disk\t\t'"$disk_usage"
    $'Memory\t\t'"$mem_usage"
    $'Last sync\t'"$(_stale_color $sync_secs)"$'\t'"$sync_msg"
  )
  command -v brew &>/dev/null &&
    info_rows+=( $'Brew\t'"$(_stale_color $brew_secs)"$'\t'"$brew_msg" )

  # Widest label sets the alignment of the value column.
  local row label color value label_width=0
  for row in "${info_rows[@]}"; do
    label=${row%%$'\t'*}
    (( ${#label} > label_width )) && label_width=${#label}
  done

  local banner=$'\033[2mPowered by\033[0m \033[1mAll Tuner Labs\033[0m \033[2mS.L.\033[0m'
  local -a info_lines=( "$banner" "" )
  local -i info_width=30   # the width of the banner line, unstyled
  for row in "${info_rows[@]}"; do
    label=${row%%$'\t'*}
    color=${${row#*$'\t'}%%$'\t'*}
    value=${row##*$'\t'}
    info_lines+=( $'\033[2m'"${(l:label_width:)label}:"$'\033[0m '"$color$value"$'\033[0m' )
    (( label_width + 2 + ${#value} > info_width )) && info_width=$(( label_width + 2 + ${#value} ))
  done

  # Side by side when there is room, info alone in a narrow terminal.
  local -i i
  if (( COLUMNS >= logo_width + gutter + info_width )); then
    local -i col=$(( logo_width + gutter + 1 ))
    local -i drawn=0
    _has_graphics && { _draw_mark; drawn=1 }
    for (( i = 1; i <= ${#logo_lines} || i <= ${#info_lines}; i++ )); do
      (( drawn )) || printf '\033[38;2;91;35;51m%s\033[0m' "${logo_lines[i]}"
      (( i <= ${#info_lines} )) && printf '\033[%dG%b' $col "${info_lines[i]}"
      printf '\n'
    done
  else
    for (( i = 1; i <= ${#info_lines}; i++ )); do
      printf '%b\n' "${info_lines[i]}"
    done
  fi

  unset -f _stale_color _relative_time _has_graphics _draw_mark
  echo ""
fi
