#!/bin/zsh
# Claude Code status line — sleek, multi-line, full-featured

input=$(cat)

# ── Extract all available fields ────────────────────────────────────────────
cwd=$(echo "$input"           | jq -r '.workspace.current_dir // .cwd // ""')
project_dir=$(echo "$input"   | jq -r '.workspace.project_dir // ""')
added_dirs=$(echo "$input"    | jq -r '.workspace.added_dirs // [] | join(" ")' 2>/dev/null)
model_name=$(echo "$input"    | jq -r '.model.display_name // ""')
model_id=$(echo "$input"      | jq -r '.model.id // ""')
version=$(echo "$input"       | jq -r '.version // ""')
session_name=$(echo "$input"  | jq -r '.session_name // ""')
output_style=$(echo "$input"  | jq -r '.output_style.name // ""')
vim_mode=$(echo "$input"      | jq -r '.vim.mode // ""')
agent_name=$(echo "$input"    | jq -r '.agent.name // ""')
agent_type=$(echo "$input"    | jq -r '.agent.type // ""')
used_pct=$(echo "$input"      | jq -r '.context_window.used_percentage // empty')
remaining_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
ctx_size=$(echo "$input"      | jq -r '.context_window.context_window_size // empty')
in_tokens=$(echo "$input"     | jq -r '.context_window.current_usage.input_tokens // empty')
out_tokens=$(echo "$input"    | jq -r '.context_window.current_usage.output_tokens // empty')
cache_read=$(echo "$input"    | jq -r '.context_window.current_usage.cache_read_input_tokens // empty')
cache_write=$(echo "$input"   | jq -r '.context_window.current_usage.cache_creation_input_tokens // empty')
total_in=$(echo "$input"      | jq -r '.context_window.total_input_tokens // empty')
total_out=$(echo "$input"     | jq -r '.context_window.total_output_tokens // empty')

# ── Nerd Font icons (explicit Unicode codepoints — Fira Code Nerd Font) ──────
ICO_FOLDER=$'\uf07b'    # nf-fa-folder          U+F07B
ICO_PROJECT=$'\uf0e8'   # nf-fa-sitemap         U+F0E8
ICO_ADDDIR=$'\uf07c'    # nf-fa-folder_open     U+F07C
ICO_BRANCH=$'\ue0a0'    # nf-pl-branch          U+E0A0
ICO_DIRTY=$'\uf111'     # nf-fa-circle          U+F111
ICO_AHEAD=$'\uf0aa'     # nf-fa-arrow_circle_up U+F0AA
ICO_BEHIND=$'\uf0ab'    # nf-fa-arrow_circle_dn U+F0AB
ICO_AGENT=$'\uf2db'     # nf-fa-microchip       U+F2DB
ICO_MODEL=$'\uf120'     # nf-fa-terminal        U+F120
ICO_TAG=$'\uf02b'       # nf-fa-tag             U+F02B
ICO_SESSION=$'\uf02e'   # nf-fa-bookmark        U+F02E
ICO_STYLE=$'\uf1de'     # nf-fa-sliders         U+F1DE
ICO_VIM=$'\ue62b'       # nf-custom-vim         U+E62B
ICO_CTX=$'\uf080'       # nf-fa-bar_chart       U+F080
ICO_IN=$'\uf063'        # nf-fa-arrow_down      U+F063  (input tokens)
ICO_OUT=$'\uf062'       # nf-fa-arrow_up        U+F062  (output tokens)
ICO_CACHE=$'\uf0e7'     # nf-fa-bolt            U+F0E7  (cache reads)
ICO_WRITE=$'\uf040'     # nf-fa-pencil          U+F040  (cache writes)
ICO_TOTAL=$'\uf1c0'     # nf-fa-database        U+F1C0  (session totals)

# ── Colors ───────────────────────────────────────────────────────────────────
R='\033[0m'
BLU='\033[34m'
CYN='\033[36m'
GRN='\033[32m'
YLW='\033[33m'
RED='\033[31m'
MAG='\033[35m'
GRY='\033[90m'

SEP=$(printf '%b' "${GRY}│${R}")

# ── Helper: shorten path ──────────────────────────────────────────────────────
shorten_path() {
  echo "${1/#$HOME/\~}"
}

# ── Git info ─────────────────────────────────────────────────────────────────
git_branch="" git_dirty="" git_ahead="" git_behind=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  git_branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
               || GIT_OPTIONAL_LOCKS=0 git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  if ! GIT_OPTIONAL_LOCKS=0 git -C "$cwd" diff --quiet 2>/dev/null || \
     ! GIT_OPTIONAL_LOCKS=0 git -C "$cwd" diff --cached --quiet 2>/dev/null; then
    git_dirty=" $ICO_DIRTY"
  fi
  ab=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" rev-list --left-right --count "@{upstream}...HEAD" 2>/dev/null)
  if [ -n "$ab" ]; then
    behind=$(echo "$ab" | awk '{print $1}')
    ahead=$(echo "$ab"  | awk '{print $2}')
    [ "$ahead"  -gt 0 ] 2>/dev/null && git_ahead=" ${ICO_AHEAD}${ahead}"
    [ "$behind" -gt 0 ] 2>/dev/null && git_behind=" ${ICO_BEHIND}${behind}"
  fi
fi

# ── Context bar (16 chars wide) ───────────────────────────────────────────────
ctx_bar="" bar_color="$GRN"
if [ -n "$used_pct" ]; then
  used_int=$(printf '%.0f' "$used_pct")
  bar_width=16
  filled=$(( used_int * bar_width / 100 ))
  empty=$(( bar_width - filled ))
  if   [ "$used_int" -ge 80 ]; then bar_color="$RED"
  elif [ "$used_int" -ge 50 ]; then bar_color="$YLW"
  fi
  bar_filled=$(printf '%*s' "$filled" '' | tr ' ' '▪')
  bar_empty=$(printf '%*s'  "$empty"  '' | tr ' ' '·')
  ctx_bar=$(printf '%b%s%b%s' "$bar_color" "$bar_filled" "$GRY" "$bar_empty")
fi

# ════════════════════════════════════════════════════════════════════════════
# LINE 1 — Directory · Git · Agent
# ════════════════════════════════════════════════════════════════════════════
short_cwd=$(shorten_path "$cwd")
line1=$(printf '%b%s %s%b' "$BLU" "$ICO_FOLDER" "$short_cwd" "$R")

if [ -n "$project_dir" ] && [ "$project_dir" != "$cwd" ]; then
  short_proj=$(shorten_path "$project_dir")
  line1=$(printf '%s %b%s %s%b' "$line1" "$GRY" "$ICO_PROJECT" "$short_proj" "$R")
fi

if [ -n "$added_dirs" ]; then
  line1=$(printf '%s %b%s %s%b' "$line1" "$GRY" "$ICO_ADDDIR" "$added_dirs" "$R")
fi

if [ -n "$git_branch" ]; then
  git_label=$(printf '%b%s %s%b%b%s%b' "$MAG" "$ICO_BRANCH" "$git_branch" "$R" "$YLW" "$git_dirty" "$R")
  sync_info=""
  if [ -n "$git_ahead" ] || [ -n "$git_behind" ]; then
    sync_info=$(printf ' %b%s%s%b' "$CYN" "$git_ahead" "$git_behind" "$R")
  fi
  line1=$(printf '%s  %s%s' "$line1" "$git_label" "$sync_info")
fi

if [ -n "$agent_name" ]; then
  agent_label="$agent_name"
  [ -n "$agent_type" ] && agent_label="$agent_name/$agent_type"
  line1=$(printf '%s  %b%s %s%b' "$line1" "$CYN" "$ICO_AGENT" "$agent_label" "$R")
fi

# ════════════════════════════════════════════════════════════════════════════
# LINE 2 — Model · Version · Session · Output style · Vim mode
# ════════════════════════════════════════════════════════════════════════════
line2=""

if [ -n "$model_name" ]; then
  line2=$(printf '%b%s %s%b' "$CYN" "$ICO_MODEL" "$model_name" "$R")
  [ -n "$model_id" ] && line2=$(printf '%s %b(%s)%b' "$line2" "$GRY" "$model_id" "$R")
fi

if [ -n "$version" ]; then
  [ -n "$line2" ] && line2=$(printf '%s  %s' "$line2" "$SEP")
  line2=$(printf '%s  %b%s %s%b' "$line2" "$GRY" "$ICO_TAG" "$version" "$R")
fi

if [ -n "$session_name" ]; then
  [ -n "$line2" ] && line2=$(printf '%s  %s' "$line2" "$SEP")
  line2=$(printf '%s  %b%s%b %s' "$line2" "$GRY" "$ICO_SESSION" "$R" "$session_name")
fi

if [ -n "$output_style" ] && [ "$output_style" != "default" ]; then
  [ -n "$line2" ] && line2=$(printf '%s  %s' "$line2" "$SEP")
  line2=$(printf '%s  %b%s%b %s' "$line2" "$GRY" "$ICO_STYLE" "$R" "$output_style")
fi

if [ -n "$vim_mode" ]; then
  [ -n "$line2" ] && line2=$(printf '%s  %s' "$line2" "$SEP")
  vim_color="$YLW"
  [ "$vim_mode" = "INSERT" ] && vim_color="$GRN"
  line2=$(printf '%s  %b%s %s%b' "$line2" "$vim_color" "$ICO_VIM" "$vim_mode" "$R")
fi

# ════════════════════════════════════════════════════════════════════════════
# LINE 3 — Context window · Token breakdown · Session totals
# ════════════════════════════════════════════════════════════════════════════
line3=""

if [ -n "$used_pct" ]; then
  used_int=$(printf '%.0f' "$used_pct")

  ctx_k=""
  [ -n "$ctx_size" ] && ctx_k=$(printf '%dk' "$(( ctx_size / 1000 ))")

  line3=$(printf '%b%s%b %s  %b%d%%%b used' "$GRY" "$ICO_CTX" "$R" "$ctx_bar" "$bar_color" "$used_int" "$R")
  [ -n "$ctx_k" ] && line3=$(printf '%s %b/ %s window%b' "$line3" "$GRY" "$ctx_k" "$R")

  if [ -n "$in_tokens" ]; then
    tok=$(printf '%b%s%b %b%s%b' "$GRY" "$ICO_IN" "$R" "$GRY" "$in_tokens" "$R")
    [ -n "$out_tokens" ]  && tok=$(printf '%s  %b%s%b %b%s%b' "$tok" "$GRY" "$ICO_OUT"   "$R" "$GRY" "$out_tokens"  "$R")
    [ -n "$cache_read" ]  && tok=$(printf '%s  %b%s%b %b%s%b' "$tok" "$GRY" "$ICO_CACHE" "$R" "$GRY" "$cache_read"  "$R")
    [ -n "$cache_write" ] && tok=$(printf '%s  %b%s%b %b%s%b' "$tok" "$GRY" "$ICO_WRITE" "$R" "$GRY" "$cache_write" "$R")
    line3=$(printf '%s  %s  %s' "$line3" "$SEP" "$tok")
  fi

  if [ -n "$total_in" ]; then
    line3=$(printf '%s  %s  %b%s%b %b%s%b in  %b%s%b out' \
      "$line3" "$SEP" "$GRY" "$ICO_TOTAL" "$R" "$GRY" "$total_in" "$R" "$GRY" "$total_out" "$R")
  fi
fi

# ════════════════════════════════════════════════════════════════════════════
# OUTPUT
# ════════════════════════════════════════════════════════════════════════════
output=""
for line in "$line1" "$line2" "$line3"; do
  if [ -n "$line" ]; then
    output="${output:+$output$'\n'}$line"
  fi
done

printf '%b%s%b' "" "$output" "$R"
