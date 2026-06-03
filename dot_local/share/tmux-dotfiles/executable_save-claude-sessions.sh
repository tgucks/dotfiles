#!/usr/bin/env bash
# tmux-resurrect post-save-all hook. Walks every tmux pane looking for a
# claude process in its descendant tree, reads the session-track state
# file written by Claude's SessionStart hook, and writes a sidecar JSON
# next to the resurrect save so our restore hook can read it back.

set -euo pipefail

STATE_DIR="${CLAUDE_RESURRECT_STATE_DIR:-${TMPDIR:-/tmp}/claude-resurrect}"
OUT_DIR="${CLAUDE_RESURRECT_SIDECAR_DIR:-$HOME/.local/share/tmux-resurrect-dotfiles}"
OUT_FILE="$OUT_DIR/claude-sessions.json"

mkdir -p "$OUT_DIR"

[[ -d "$STATE_DIR" ]] || { echo "[]" > "$OUT_FILE"; exit 0; }

ps_snapshot=$(ps -eo pid=,ppid=,comm=)

# descendants <root_pid> — echoes all pids in the subtree rooted at root_pid
descendants() {
  local root=$1
  awk -v root="$root" '
    { parent[$1]=$2; comm[$1]=$3 }
    END {
      # BFS from root
      n=1; queue[1]=root
      while (n>0) {
        cur=queue[n]; delete queue[n]; n--
        for (p in parent) if (parent[p]==cur) { print p " " comm[p]; n++; queue[n]=p }
      }
    }
  ' <<<"$ps_snapshot"
}

entries=()
# We persist the STABLE pane identity (session:window.pane_index), not the
# ephemeral pane_id (%N): tmux reassigns pane ids from scratch when the server
# restarts (reboot -> continuum-boot), so a saved %N matches nothing after a
# restart. tmux-resurrect itself keys panes on session/window/pane index, and
# those values survive a restore, so we mirror that to relocate the pane.
# pane_pid is only used now, to find the live claude process.
while IFS=$'\t' read -r session_name window_index pane_index pane_pid; do
  [[ -z "$pane_pid" ]] && continue
  # Find the claude process in this pane's subtree
  claude_pid=$(descendants "$pane_pid" | awk '$2=="claude" {print $1; exit}')
  [[ -z "$claude_pid" ]] && continue

  state_file="$STATE_DIR/claude-$claude_pid.json"
  [[ -r "$state_file" ]] || continue

  target="${session_name}:${window_index}.${pane_index}"
  entries+=("$(jq -c --arg target "$target" '. + {target: $target}' "$state_file")")
done < <(tmux list-panes -a -F '#{session_name}	#{window_index}	#{pane_index}	#{pane_pid}')

if ((${#entries[@]} == 0)); then
  echo '{"sessions":[]}' > "$OUT_FILE"
else
  printf '%s\n' "${entries[@]}" | jq -s '{sessions: .}' > "$OUT_FILE"
fi
