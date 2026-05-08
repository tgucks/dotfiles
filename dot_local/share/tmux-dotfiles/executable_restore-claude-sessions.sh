#!/usr/bin/env bash
# tmux-resurrect post-restore-all hook. Reads the sidecar JSON written by
# the save hook and re-launches claude --resume in each pane. Assumes
# tmux-resurrect has already restored the pane layout and cwds.

set -euo pipefail

IN_FILE="$HOME/.local/share/tmux-resurrect-dotfiles/claude-sessions.json"
[[ -r "$IN_FILE" ]] || exit 0

posix_quote() {
  printf "'%s'" "${1//\'/\'\"\'\"\'}"
}

jq -c '.sessions[]' "$IN_FILE" 2>/dev/null | while read -r entry; do
  pane=$(jq -r '.pane // empty' <<<"$entry")
  sid=$(jq -r '.session_id // empty' <<<"$entry")
  cwd=$(jq -r '.cwd // empty' <<<"$entry")
  [[ -z "$pane" || -z "$sid" ]] && continue

  tmux list-panes -a -F '#{pane_id}' 2>/dev/null | grep -qx "$pane" || continue

  current_cmd=$(tmux display-message -t "$pane" -p '#{pane_current_command}' 2>/dev/null || true)
  case "$current_cmd" in
    bash|zsh|fish|sh|dash|ksh) ;;
    *) continue ;;
  esac

  cwd_q=$(posix_quote "${cwd:-$HOME}")
  sid_q=$(posix_quote "$sid")
  tmux send-keys -t "$pane" "cd $cwd_q 2>/dev/null; command claude --resume $sid_q" Enter
done
