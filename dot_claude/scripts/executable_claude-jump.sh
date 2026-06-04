#!/bin/bash
# Invoked by terminal-notifier's -execute when you click a Claude banner.
# Arg 1: tmux target "session:window.pane". Brings iTerm2 forward, attaches
# the right tmux session, and selects the exact pane that raised the alert.
#
# IMPORTANT: NotificationCenter launches -execute with a minimal PATH
# (/usr/bin:/bin:...) that does NOT include /opt/homebrew/bin, so `tmux` is not
# on PATH here. We resolve it to an absolute path. Errors are logged (not
# swallowed) to ~/.claude/claude-jump.log for debugging.
set -u

LOG="$HOME/.claude/claude-jump.log"
log() { printf '%s %s\n' "$(date '+%H:%M:%S')" "$*" >>"$LOG" 2>/dev/null; }

TARGET="${1:-}"
log "invoked target='$TARGET' PATH='$PATH'"
[ -z "$TARGET" ] && exit 0

# Resolve tmux to an absolute path (PATH is bare under NotificationCenter).
TMUX_BIN=""
for p in /opt/homebrew/bin/tmux /usr/local/bin/tmux "$(command -v tmux 2>/dev/null)"; do
  [ -n "$p" ] && [ -x "$p" ] && { TMUX_BIN="$p"; break; }
done

SESSION=${TARGET%%:*}

if [ -n "$TMUX_BIN" ] && "$TMUX_BIN" has-session -t "$SESSION" 2>>"$LOG"; then
  # Set the session's active window+pane, then move the client onto it.
  "$TMUX_BIN" select-window -t "$TARGET" 2>>"$LOG"
  "$TMUX_BIN" select-pane   -t "$TARGET" 2>>"$LOG"
  "$TMUX_BIN" switch-client -t "$TARGET" 2>>"$LOG" || true
  # Clear the alert highlight on arrival (we may not be the focused client,
  # so do it explicitly rather than relying on the after-select hook).
  WIN_TARGET=${TARGET%.*}
  "$TMUX_BIN" set -wu -t "$WIN_TARGET" @claude-alerted 2>>"$LOG"
  "$TMUX_BIN" set -wu -t "$WIN_TARGET" window-status-format 2>>"$LOG"
  "$TMUX_BIN" set -wu -t "$WIN_TARGET" window-status-current-format 2>>"$LOG"
  log "navigated to $TARGET"
else
  log "tmux not usable (bin='$TMUX_BIN') or no session '$SESSION'"
fi

# Raise iTerm2 so the click surfaces the terminal.
/usr/bin/osascript -e 'tell application "iTerm2" to activate' >>"$LOG" 2>&1 \
  || /usr/bin/osascript -e 'tell application "iTerm" to activate' >>"$LOG" 2>&1 || true

exit 0
