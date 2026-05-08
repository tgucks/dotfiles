#!/usr/bin/env bash
# Claude SessionStart hook. Claude pipes session-start JSON on stdin.
# We extract session_id + cwd and stash them keyed by the claude process
# PID so tmux-resurrect's post-save-all hook can look them up per pane.

set -euo pipefail

STATE_DIR="${TMPDIR:-/tmp}/claude-resurrect"
mkdir -p -m 0700 "$STATE_DIR"

INPUT="$(cat)"

# Claude may spawn us via `sh -c`, so $PPID isn't necessarily claude itself.
# Walk up at most 5 hops looking for a process whose comm is exactly `claude`.
find_claude_pid() {
  local pid=$PPID
  for _ in 1 2 3 4 5; do
    [[ -z "$pid" || "$pid" == "1" || "$pid" == "0" ]] && return 1
    local comm
    comm=$(ps -o comm= -p "$pid" 2>/dev/null | awk '{print $NF}')
    if [[ "$comm" == "claude" ]]; then
      echo "$pid"
      return 0
    fi
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  done
  return 1
}

CLAUDE_PID=$(find_claude_pid || echo "")
[[ -z "$CLAUDE_PID" ]] && exit 0

SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
[[ -z "$SESSION_ID" ]] && exit 0
[[ -z "$CWD" ]] && CWD="$PWD"

jq -n \
  --arg sid "$SESSION_ID" \
  --arg cwd "$CWD" \
  --argjson pid "$CLAUDE_PID" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{session_id: $sid, cwd: $cwd, pid: $pid, timestamp: $ts}' \
  > "$STATE_DIR/claude-$CLAUDE_PID.json"
