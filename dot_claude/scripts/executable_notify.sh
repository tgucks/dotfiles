#!/bin/bash
# Claude Code attention notifier. Wired to the Stop + Notification hooks.
# Claude pipes the event JSON on stdin.
#
# Behavior:
#   - Sound ALWAYS plays (via afplay, independent of the system alert sound),
#     unless notifications are disabled for this tmux session.
#   - A desktop banner appears ONLY when you are NOT looking at the pane that
#     raised it. Clicking the banner jumps you back to that pane.
#   - The pane's window tab in the status bar flickers, then stays solid until
#     you navigate onto the pane (cleared by clear-alert.sh via tmux hooks).
#
# Customize colors + sound in dot_tmux.conf (@claude-alert-bg/-fg/-notify-sound).

INPUT="$(cat)"

# --- Per-session kill switch (prefix N toggles @claude-notify-off) ---
if [ -n "$TMUX" ]; then
  SESS=$(tmux display -p -t "$TMUX_PANE" '#{session_name}' 2>/dev/null)
  if [ "$(tmux show-options -qv -t "$SESS" @claude-notify-off 2>/dev/null)" = "1" ]; then
    exit 0
  fi
fi

# --- Sound (always) ---
SOUND=""
[ -n "$TMUX" ] && SOUND=$(tmux show-options -gqv @claude-notify-sound 2>/dev/null)
SOUND=${SOUND:-${CLAUDE_NOTIFY_SOUND:-/System/Library/Sounds/Glass.aiff}}
[ -f "$SOUND" ] && afplay "$SOUND" >/dev/null 2>&1 &

# --- Are we already looking at the pane that raised this? ---
is_focused() {
  local pane="$1" psess pact wact
  pact=$(tmux display -p -t "$pane" '#{pane_active}' 2>/dev/null) || return 1
  wact=$(tmux display -p -t "$pane" '#{window_active}' 2>/dev/null)
  psess=$(tmux display -p -t "$pane" '#{session_name}' 2>/dev/null)
  [ "$pact" = "1" ] && [ "$wact" = "1" ] || return 1
  tmux list-clients -F '#{client_session}	#{client_flags}' 2>/dev/null \
    | awk -F'\t' -v s="$psess" '$1==s && $2 ~ /focused/ {f=1} END{exit !f}'
}

if [ -n "$TMUX" ] && is_focused "$TMUX_PANE"; then
  exit 0   # sound already fired; no banner, no highlight when you're right here
fi

# --- Build banner text from the event JSON ---
EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)
MESSAGE=$(printf '%s' "$INPUT" | jq -r '.message // empty' 2>/dev/null)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
DIR=$(basename "${CWD:-$PWD}")

case "$EVENT" in
  Notification) BODY=${MESSAGE:-"Needs your attention"} ;;
  Stop)         BODY="Finished responding" ;;
  *)            BODY=${MESSAGE:-"Needs your attention"} ;;
esac

# --- Desktop banner (only reached when unfocused) ---
NOTIFIER=$(command -v terminal-notifier 2>/dev/null || true)
for p in /opt/homebrew/bin/terminal-notifier /usr/local/bin/terminal-notifier; do
  [ -z "$NOTIFIER" ] && [ -x "$p" ] && NOTIFIER="$p"
done

if [ -n "$NOTIFIER" ]; then
  TARGET=""
  [ -n "$TMUX" ] && TARGET=$(tmux display -p -t "$TMUX_PANE" \
    '#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null)
  "$NOTIFIER" \
    -title "Claude Code" \
    -subtitle "$DIR" \
    -message "$BODY" \
    -group "${TARGET:-claude}" \
    -execute "bash $HOME/.claude/scripts/claude-jump.sh '$TARGET'" \
    >/dev/null 2>&1 &
fi

# --- Status-bar highlight: flicker, then stay solid until you navigate in ---
if [ -n "$TMUX" ]; then
  WIN=$(tmux display -p -t "$TMUX_PANE" '#{window_id}' 2>/dev/null)
  BG=$(tmux show-options -gqv @claude-alert-bg 2>/dev/null); BG=${BG:-#bd93f9}
  FG=$(tmux show-options -gqv @claude-alert-fg 2>/dev/null); FG=${FG:-#1e1e2e}
  FMT="#[bg=$BG,fg=$FG,bold] #W #[default]"

  tmux set -w -t "$WIN" @claude-alerted 1

  apply_on()  { tmux set -w -t "$WIN" window-status-format "$FMT"; tmux set -w -t "$WIN" window-status-current-format "$FMT"; }
  apply_off() { tmux set -wu -t "$WIN" window-status-format; tmux set -wu -t "$WIN" window-status-current-format; }
  still_alert() { [ "$(tmux show-options -wqv -t "$WIN" @claude-alerted 2>/dev/null)" = "1" ]; }

  (
    for _ in 1 2; do
      still_alert || exit 0
      apply_on;  sleep 0.18
      apply_off; sleep 0.12
    done
    still_alert || exit 0
    apply_on   # settle solid; clear-alert.sh removes it when you arrive
  ) &
fi

exit 0
