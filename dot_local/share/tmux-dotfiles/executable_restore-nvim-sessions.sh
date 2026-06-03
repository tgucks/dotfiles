#!/usr/bin/env bash
# tmux-resurrect post-restore-all hook. For each restored pane that is a bare
# shell, derives the pane's stable tmux coordinate (session__window__pane) and,
# if a matching per-pane auto-session file exists, relaunches the pane as
# `nvim -S <that file>` so the pane's full layout (all buffers, splits) comes
# back.
#
# nvim is deliberately EXCLUDED from tmux-resurrect's own process relaunch
# (see @resurrect-default-processes in tmux.conf) so this hook is the single
# owner of nvim restoration. We never inject `+AutoSession restore` / `--resume`
# against the cwd-shared session file - per-pane files cannot collide, which is
# the whole point (see the auto-session x tmux-resurrect contract).
#
# Panes with no saved per-pane session are left as shells, untouched.

set -euo pipefail

# auto-session's root_dir. Override for tests via NVIM_RESURRECT_SESSION_DIR.
SESSION_DIR="${NVIM_RESURRECT_SESSION_DIR:-$HOME/.local/share/nvim/sessions}"
[[ -d "$SESSION_DIR" ]] || exit 0

posix_quote() {
  printf "'%s'" "${1//\'/\'\"\'\"\'}"
}

# Mirror core/tmux_session.lua: sanitize a tmux session name to [A-Za-z0-9_],
# every other char -> '-', so the filename matches what nvim wrote.
sanitize() {
  printf '%s' "$1" | sed 's/[^[:alnum:]_]/-/g'
}

while IFS=$'\t' read -r session_name window_index pane_index pane_id; do
  [[ -z "$pane_id" ]] && continue

  # Only act on panes that came back as a bare shell (resurrect did not, and
  # must not, relaunch nvim itself).
  current_cmd=$(tmux display-message -t "$pane_id" -p '#{pane_current_command}' 2>/dev/null || true)
  case "$current_cmd" in
    bash|zsh|fish|sh|dash|ksh) ;;
    *) continue ;;
  esac

  coord="$(sanitize "$session_name")__${window_index}__${pane_index}"
  sess_file="$SESSION_DIR/tmux__${coord}.vim"
  [[ -r "$sess_file" ]] || continue

  sess_q=$(posix_quote "$sess_file")
  tmux send-keys -t "$pane_id" "command nvim -S $sess_q" Enter
done < <(tmux list-panes -a -F '#{session_name}	#{window_index}	#{pane_index}	#{pane_id}')
