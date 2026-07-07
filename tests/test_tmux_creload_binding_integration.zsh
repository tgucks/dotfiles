#!/usr/bin/env zsh
# Integration test: prefix C-r reloads ~/.tmux.conf instead of running
# tmux-resurrect's restore script.
#
# Loads the real deployed ~/.tmux.conf into an isolated tmux server (its
# own socket, so it can't disturb a real session) and asserts the C-r
# binding in the prefix table points at `source-file`, not resurrect's
# restore.sh. tmux key tables hold exactly one binding per key, so
# `list-keys` shows whichever bind won after all config/plugins load.
#
# Run: zsh tests/test_tmux_creload_binding_integration.zsh

emulate -L zsh
set -u

TMUX_CONF="${TMUX_CONF:-$HOME/.tmux.conf}"
SOCKET="tmux-creload-test-$$"
TMUXCMD=(tmux -L "$SOCKET")

[[ -r "$TMUX_CONF" ]] || { print "FAIL: $TMUX_CONF not found (did you run \`chezmoi apply\`?)"; exit 1; }
[[ -x "$HOME/.tmux/plugins/tpm/tpm" ]] || { print "SKIP: tpm not installed"; exit 0; }
[[ -x "$HOME/.tmux/plugins/tmux-resurrect/scripts/restore.sh" ]] || { print "SKIP: tmux-resurrect not installed"; exit 0; }

cleanup() { $TMUXCMD kill-server 2>/dev/null }
trap cleanup EXIT INT TERM

$TMUXCMD -f "$TMUX_CONF" new-session -d -s test || { print "FAIL: could not start test server"; exit 1; }
sleep 1

binding_line=$($TMUXCMD list-keys -T prefix | grep -E '(^|[[:space:]])C-r([[:space:]]|$)')

if [[ -z "$binding_line" ]]; then
  print "FAIL: no C-r binding found in prefix table"
  exit 1
fi
print "C-r binding: $binding_line"

if [[ "$binding_line" == *source-file* ]] && [[ "$binding_line" != *restore.sh* ]]; then
  print "PASS: prefix C-r is bound to source-file (config reload), not resurrect restore"
  exit 0
else
  print "FAIL: prefix C-r is not bound to source-file: $binding_line"
  exit 1
fi
