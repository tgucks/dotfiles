#!/usr/bin/env bash
# Custom @-mention file picker for Claude Code.
# Reads a JSON payload on stdin (with .query and .cwd), prints up to 15
# ranked relative paths on stdout. Claude Code keeps only the first 15.

set -euo pipefail

# PATH is bare when Claude Code invokes this, so resolve each tool explicitly.
_resolve() {
  local name=$1 p
  for p in "/opt/homebrew/bin/$name" "/usr/local/bin/$name" "$(command -v "$name" 2>/dev/null)"; do
    [ -n "$p" ] && [ -x "$p" ] && { printf '%s' "$p"; return 0; }
  done
  return 1
}

JQ=$(_resolve jq) || exit 0
FZF=$(_resolve fzf) || exit 0
FD=$(_resolve fd) || exit 0

payload=$(cat)
query=$($JQ -r '.query // ""' <<<"$payload")

cd "${CLAUDE_PROJECT_DIR:-$PWD}"

candidates=$(git ls-files --cached --others --exclude-standard 2>/dev/null || true)
if [[ -z "$candidates" ]]; then
  candidates=$("$FD" --type f --hidden --exclude .git 2>/dev/null || true)
fi

[[ -z "$candidates" ]] && exit 0

if [[ -z "$query" ]]; then
  printf '%s\n' "$candidates" | head -n 15
else
  printf '%s\n' "$candidates" | "$FZF" --filter="$query" | head -n 15
fi
