#!/usr/bin/env bash
# tmux-resurrect post-save-all hook. Walks every tmux pane looking for a
# claude process in its descendant tree, reads the session-track state
# file written by Claude's SessionStart hook, and writes a sidecar JSON
# next to the resurrect save so our restore hook can read it back.

set -euo pipefail

STATE_DIR="${TMPDIR:-/tmp}/claude-resurrect"
OUT_DIR="$HOME/.local/share/tmux-resurrect-dotfiles"
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
while IFS=$'\t' read -r pane_id pane_pid; do
  [[ -z "$pane_pid" ]] && continue
  # Find the claude process in this pane's subtree
  claude_pid=$(descendants "$pane_pid" | awk '$2=="claude" {print $1; exit}')
  [[ -z "$claude_pid" ]] && continue

  state_file="$STATE_DIR/claude-$claude_pid.json"
  [[ -r "$state_file" ]] || continue

  entries+=("$(jq -c --arg pane "$pane_id" '. + {pane: $pane}' "$state_file")")
done < <(tmux list-panes -a -F '#{pane_id}	#{pane_pid}')

if ((${#entries[@]} == 0)); then
  echo '{"sessions":[]}' > "$OUT_FILE"
else
  printf '%s\n' "${entries[@]}" | jq -s '{sessions: .}' > "$OUT_FILE"
fi
