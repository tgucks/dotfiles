#!/bin/bash
# Bound to tmux after-select-pane / after-select-window hooks. When you land
# on a window that was flagged by notify.sh (@claude-alerted), drop the flag
# and restore the default status-bar formatting for that window.
set -u

[ -n "${TMUX:-}" ] || exit 0

WIN=$(tmux display -p '#{window_id}' 2>/dev/null) || exit 0
[ "$(tmux show-options -wqv -t "$WIN" @claude-alerted 2>/dev/null)" = "1" ] || exit 0

tmux set -wu -t "$WIN" @claude-alerted 2>/dev/null
tmux set -wu -t "$WIN" window-status-format 2>/dev/null
tmux set -wu -t "$WIN" window-status-current-format 2>/dev/null
exit 0
