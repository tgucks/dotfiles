#!/usr/bin/env bash
# tmux-resurrect post-restore-all hook. Reads the sidecar JSON written by
# the save hook and re-launches claude --resume in each pane. Assumes
# tmux-resurrect has already restored the pane layout and cwds.

set -euo pipefail

IN_FILE="${CLAUDE_RESURRECT_SIDECAR_DIR:-$HOME/.local/share/tmux-resurrect-dotfiles}/claude-sessions.json"
[[ -r "$IN_FILE" ]] || exit 0

posix_quote() {
  printf "'%s'" "${1//\'/\'\"\'\"\'}"
}

jq -c '.sessions[]' "$IN_FILE" 2>/dev/null | while read -r entry; do
  # `target` is the stable session:window.pane_index identity written by the
  # save hook. Older sidecars used `pane` (an ephemeral %N) - accept it as a
  # fallback so a sidecar saved before this change still restores.
  target=$(jq -r '.target // .pane // empty' <<<"$entry")
  sid=$(jq -r '.session_id // empty' <<<"$entry")
  cwd=$(jq -r '.cwd // empty' <<<"$entry")
  [[ -z "$target" || -z "$sid" ]] && continue

  # Resolve the stable target to the pane's CURRENT ephemeral id. tmux accepts
  # session:window.pane targets directly, but we normalize to %N so the later
  # commands address one unambiguous pane. A target that no longer exists
  # (pane closed before save, or a stale %N) resolves to nothing -> skip.
  pane=$(tmux display-message -t "$target" -p '#{pane_id}' 2>/dev/null || true)
  [[ -z "$pane" ]] && continue
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
