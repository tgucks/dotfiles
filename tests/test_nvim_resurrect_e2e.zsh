#!/usr/bin/env zsh
# End-to-end test: tmux-resurrect restores an nvim pane after a server
# restart, relaunching it VERBATIM - no injected --resume / +SessionRestore
# / -S. nvim is restored natively by resurrect (it is in the default process
# list, keyed on the stable session:window.pane_index identity), so no custom
# sidecar is involved. This guards the auto-session x resurrect contract:
# resurrect must re-run the saved command as-is, never inject a session
# restore that would collide on swapfiles across multiple nvim panes.
#
# Runs against an ISOLATED tmux server with a scratch @resurrect-dir, so it
# never touches the user's live resurrect state.
#
# Run: zsh tests/test_nvim_resurrect_e2e.zsh

emulate -L zsh
set -u

SOCKET="nvim-resurrect-test-$$"
TMUX=(tmux -L "$SOCKET")
NVIM="${NVIM_BIN:-/opt/homebrew/bin/nvim}"
RES=~/.tmux/plugins/tmux-resurrect

if [[ ! -x "$NVIM" ]]; then print "SKIP: $NVIM not executable"; exit 0; fi
if [[ ! -x "$RES/scripts/save.sh" ]]; then print "SKIP: tmux-resurrect not installed"; exit 0; fi

SCRATCH=$(mktemp -d)
RESURRECT_DIR="$SCRATCH/resurrect"
mkdir -p "$RESURRECT_DIR"
print "hello world" > "$SCRATCH/note.txt"

cleanup() {
  $TMUX kill-server 2>/dev/null
  rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$SOCKET" 2>/dev/null
  rm -rf "$SCRATCH"
}
trap cleanup EXIT INT TERM
fail() { print "FAIL: $*"; exit 1; }

# --- build session: launch nvim the way the user does (bare `nvim` via PATH).
# resurrect's ps strategy records `ps args` of the pane child; a PATH-launched
# nvim records as `nvim note.txt`, which matches resurrect's ^nvim matcher.
$TMUX new-session -d -s work -c "$SCRATCH" -x 200 -y 50 || fail "new-session"
$TMUX source-file ~/.tmux.conf 2>/dev/null
$TMUX set-option -g @resurrect-dir "$RESURRECT_DIR"
$TMUX send-keys -t work:0 "command nvim note.txt" C-m

# Wait until nvim is actually the pane's foreground process.
up=0
for _ in $(seq 1 50); do
  if $TMUX list-panes -t work:0 -F '#{pane_current_command}' 2>/dev/null | grep -qx nvim; then
    up=1; break
  fi
  sleep 0.1
done
(( up )) || fail "nvim never came up in pane"

# --- save, then verify the saved command is restorable (matches ^nvim).
$TMUX run-shell "$RES/scripts/save.sh" || fail "resurrect save failed"
sleep 0.5
saved_cmd=$(grep -E '^pane' "$RESURRECT_DIR/last" | grep nvim | tail -1 | awk -F'\t' '{print $NF}' | sed 's/^://')
[[ -n "$saved_cmd" ]] || fail "no nvim pane saved in resurrect state"
case "$saved_cmd" in
  nvim\ *|nvim) ;;
  *) fail "saved nvim command '$saved_cmd' will not match resurrect's ^nvim matcher (would not restore)" ;;
esac
print "saved nvim command: $saved_cmd"

# --- restart: quit nvim cleanly (avoid swap), kill server, lose pane ids.
$TMUX send-keys -t work:0 ':qa!' C-m 2>/dev/null
sleep 1
$TMUX kill-server 2>/dev/null
sleep 0.5

# Bootstrap a throwaway session (as continuum-boot would on a fresh server),
# then restore. A non-colliding bootstrap session avoids resurrect's
# "pane already exists -> skip its process" path.
$TMUX new-session -d -s boot -c "$SCRATCH" -x 200 -y 50 || fail "rebuild new-session"
$TMUX source-file ~/.tmux.conf 2>/dev/null
$TMUX set-option -g @resurrect-dir "$RESURRECT_DIR"
$TMUX run-shell "$RES/scripts/restore.sh" || fail "resurrect restore failed"

# --- assert nvim came back running in the restored pane.
back=0
for _ in $(seq 1 60); do
  if $TMUX list-panes -a -F '#{pane_current_command}' 2>/dev/null | grep -qx nvim; then
    back=1; break
  fi
  sleep 0.1
done
(( back )) || {
  print "panes: $($TMUX list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_current_command}')"
  fail "nvim was NOT restored after server restart"
}

# --- assert the relaunch was VERBATIM: no injected session-restore flags.
# Inspect the argv of the restored nvim process.
nvim_argv=$(ps -eo args= | grep -E "[n]vim note.txt" | grep -v 'tmux -L' | head -1)
[[ -n "$nvim_argv" ]] || fail "could not find restored nvim process argv"
for forbidden in '--resume' '+SessionRestore' '-S ' '+AutoSession' '--continue'; do
  if print -r -- "$nvim_argv" | grep -qF -- "$forbidden"; then
    fail "restored nvim has injected '$forbidden' (violates auto-session contract): $nvim_argv"
  fi
done

print "PASS: nvim restored verbatim ('$saved_cmd') after server restart, no injected session-restore flags"
exit 0
