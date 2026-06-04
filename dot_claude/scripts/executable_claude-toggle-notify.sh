#!/bin/bash
# Bound to `prefix N`. Toggles Claude notifications for the CURRENT tmux
# session by flipping the @claude-notify-off session option, which notify.sh
# checks before doing anything.
set -u

[ -n "${TMUX:-}" ] || exit 0

CUR=$(tmux show-options -qv @claude-notify-off 2>/dev/null)
if [ "$CUR" = "1" ]; then
  tmux set-option @claude-notify-off 0
  tmux display-message "Claude notifications: ON (this session)"
else
  tmux set-option @claude-notify-off 1
  tmux display-message "Claude notifications: OFF (this session)"
fi
