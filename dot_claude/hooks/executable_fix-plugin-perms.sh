#!/usr/bin/env bash
# Workaround for https://github.com/anthropics/claude-code/issues/38705
# Marketplace plugin extraction loses the git execute bit on .sh files,
# causing hook errors (exit 126 — permission denied) at session start.
# This hook runs early in SessionStart and restores +x on any .sh files
# that are missing it.

for dir in "$HOME/.claude/hooks" "$HOME/.claude/plugins"; do
  [ -d "$dir" ] || continue
  find "$dir" -name "*.sh" ! -perm -u+x -exec chmod +x {} \;
done

exit 0
