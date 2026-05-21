#!/usr/bin/env bash
# Custom @-mention file picker for Claude Code.
# Reads a JSON payload on stdin (with .query and .cwd), prints up to 15
# ranked relative paths on stdout. Claude Code keeps only the first 15.

set -euo pipefail

JQ=/opt/homebrew/bin/jq
FZF=/opt/homebrew/bin/fzf
FD=/opt/homebrew/bin/fd

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
