#!/usr/bin/env zsh
# End-to-end test: tmux-resurrect save -> server restart -> restore must
# relaunch `claude --resume <session_id>` in the SAME logical pane it was
# captured from.
#
# This exercises the real failure the user hit: after a reboot the tmux
# server assigns brand-new ephemeral pane ids (%N), so any restore keyed on
# the saved %N matches nothing and the claude pane comes back as a bare
# shell with the old (captured) session frozen above it.
#
# The test runs against an ISOLATED tmux server (tmux -L) with a scratch
# @resurrect-dir and scratch state/sidecar dirs, so it never touches the
# user's live resurrect state. See memory: tmux-resurrect-isolated-repro.
#
# Run: zsh tests/test_claude_resurrect_e2e.zsh

emulate -L zsh
set -u

REPO_ROOT="${0:A:h:h}"
SOCKET="claude-resurrect-test-$$"
TMUX=(tmux -L "$SOCKET")

SAVE_HOOK="$REPO_ROOT/dot_local/share/tmux-dotfiles/executable_save-claude-sessions.sh"
RESTORE_HOOK="$REPO_ROOT/dot_local/share/tmux-dotfiles/executable_restore-claude-sessions.sh"

for f in "$SAVE_HOOK" "$RESTORE_HOOK"; do
  [[ -r "$f" ]] || { print "FAIL: missing $f"; exit 1; }
done

RES=~/.tmux/plugins/tmux-resurrect
if [[ ! -x "$RES/scripts/save.sh" ]]; then
  print "SKIP: tmux-resurrect not installed at $RES"
  exit 0
fi

# --- scratch sandbox ---
SCRATCH=$(mktemp -d)
RESURRECT_DIR="$SCRATCH/resurrect"
STATE_DIR="$SCRATCH/state"           # stand-in for $TMPDIR/claude-resurrect
SIDECAR_DIR="$SCRATCH/sidecar"        # stand-in for ~/.local/share/tmux-resurrect-dotfiles
FAKEBIN="$SCRATCH/bin"                # holds the fake `claude`
RELAUNCH_LOG="$SCRATCH/relaunch.log"  # the fake claude appends its argv here
mkdir -p "$RESURRECT_DIR" "$STATE_DIR" "$SIDECAR_DIR" "$FAKEBIN"

# Two fakes share one name `claude` on PATH, used in different phases:
#
#  SAVE phase: a symlink to /bin/sleep. PATH-invoked as `claude`, macOS reports
#    comm=claude (the real binary does too), so the save hook's `comm==claude`
#    descendant matcher fires. Launched with a valid sleep arg so it stays up;
#    its argv is irrelevant to save (the session_id comes from the state file).
#
#  RESTORE phase: a shebang script that logs its argv then sleeps. The restore
#    hook types `command claude --resume <sid>` into the resolved pane; the
#    logger captures that argv, proving the hook targeted a real restored pane
#    with the correct session id. (comm here is /bin/sh, which is fine - the
#    restore assertion is about the typed command, not comm.)
make_save_fake()    { rm -f "$FAKEBIN/claude"; ln -s /bin/sleep "$FAKEBIN/claude"; }
make_restore_fake() {
  rm -f "$FAKEBIN/claude"
  cat > "$FAKEBIN/claude" <<EOF
#!/bin/sh
echo "RELAUNCHED \$*" >> "$RELAUNCH_LOG"
exec sleep 300
EOF
  chmod +x "$FAKEBIN/claude"
}
make_save_fake

SESSION_ID="e2e-sid-$$-abcdef"

cleanup() {
  $TMUX kill-server 2>/dev/null
  rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$SOCKET" 2>/dev/null
  rm -rf "$SCRATCH"
}
trap cleanup EXIT INT TERM

fail() { print "FAIL: $*"; exit 1; }

# --- build the initial session ---
$TMUX new-session -d -s work -c "$SCRATCH" -x 200 -y 50 || fail "new-session"
$TMUX source-file ~/.tmux.conf 2>/dev/null
$TMUX set-option -g @resurrect-dir "$RESURRECT_DIR"
# capture-pane-contents on: reproduces the "frozen old session" cosmetic too
$TMUX set-option -g @resurrect-capture-pane-contents 'on'

# Churn pane ids BEFORE creating the claude pane. tmux assigns pane ids
# monotonically per server and never reuses them within a server's life; a
# fresh server after restart resets the counter to %0. By burning several ids
# now, the claude pane gets a HIGH id (%N) that a freshly-restarted server
# (which only recreates 2 panes -> %0,%1) can never reassign. This makes the
# real-world reboot failure - saved %N matches nothing - deterministic.
for _ in 1 2 3 4 5 6; do
  $TMUX new-window -t work: -c "$SCRATCH"
  $TMUX kill-window -t "work:\$"
done

# window 0 pane 0: a plain shell (control pane, should stay a shell)
# new window: the claude pane (gets a high ephemeral id after the churn)
claude_win=$($TMUX new-window -P -F '#{window_id}' -t work: -c "$SCRATCH")
[[ -n "$claude_win" ]] || fail "could not create claude window"

# Launch the save-phase fake (symlink->sleep) via PATH so comm==claude.
# Arg is a valid sleep duration so the process stays up; the real session id
# is supplied via the state file below, not argv.
$TMUX send-keys -t "$claude_win" "export PATH=\"$FAKEBIN:\$PATH\"; claude 300" C-m

# Resolve the claude window's pane id + pane_pid.
claude_pane=$($TMUX list-panes -a -F '#{window_id} #{pane_id}' | awk -v w="$claude_win" '$1==w{print $2}')
claude_pane_pid=$($TMUX list-panes -a -F '#{window_id} #{pane_pid}' | awk -v w="$claude_win" '$1==w{print $2}')
[[ -n "$claude_pane_pid" ]] || fail "could not find claude pane pid"

# Wait for a `claude` process (by ps comm, exactly as the save hook matches)
# to appear in the pane's descendant tree. NOTE: tmux's pane_current_command
# resolves the symlink and reports `sleep`; only `ps comm` shows the invoked
# name `claude`, which is what the save hook keys on - so probe with ps.
find_claude_in_subtree() {
  ps -eo pid=,ppid=,comm= | awk -v root="$1" '
    { parent[$1]=$2; comm[$1]=$3 }
    END { n=1; q[1]=root
          while(n>0){ c=q[n]; delete q[n]; n--
            for(p in parent) if(parent[p]==c){ if(comm[p]=="claude"){print p; exit} ; n++; q[n]=p } } }'
}

claude_pid=""
for _ in $(seq 1 50); do
  claude_pid=$(find_claude_in_subtree "$claude_pane_pid")
  [[ -n "$claude_pid" ]] && break
  sleep 0.1
done
[[ -n "$claude_pid" ]] || fail "fake claude (comm=claude) never came up in pane subtree"

# --- write the SessionStart state file the save hook expects ---
# Keyed by the claude pid in this pane's subtree, exactly as the real
# SessionStart hook would have written it.
cat > "$STATE_DIR/claude-$claude_pid.json" <<EOF
{"session_id":"$SESSION_ID","cwd":"$SCRATCH","pid":$claude_pid,"timestamp":"2026-01-01T00:00:00Z"}
EOF

# --- SAVE: run resurrect save (fires post-save-all -> our save hook) ---
# Drive the save hook directly with the sandbox env so it writes the sidecar
# into our scratch dir. We invoke the resurrect save first (writes the pane
# layout), then the claude save hook exactly as the post-save-all hook would.
$TMUX run-shell "$RES/scripts/save.sh" || fail "resurrect save.sh failed"
sleep 0.5

# tmux run-shell executes in the SERVER's environment, so sandbox overrides
# must be inlined into the command string (env vars on the `tmux` client line
# would not propagate to the server-side hook process).
$TMUX run-shell "CLAUDE_RESURRECT_STATE_DIR='$STATE_DIR' CLAUDE_RESURRECT_SIDECAR_DIR='$SIDECAR_DIR' bash '$SAVE_HOOK'" \
  || fail "save hook failed"
sleep 0.3

SIDECAR="$SIDECAR_DIR/claude-sessions.json"
[[ -r "$SIDECAR" ]] || fail "save hook did not write sidecar at $SIDECAR"
got_sid=$(jq -r '.sessions[0].session_id // empty' "$SIDECAR" 2>/dev/null)
[[ "$got_sid" == "$SESSION_ID" ]] || fail "sidecar missing our session (got '$got_sid'); contents: $(cat "$SIDECAR")"

# The sidecar must persist the STABLE target, never the ephemeral %N pane id.
saved_target=$(jq -r '.sessions[0].target // empty' "$SIDECAR" 2>/dev/null)
[[ -n "$saved_target" ]] || fail "sidecar has no stable 'target' field; contents: $(cat "$SIDECAR")"
[[ "$saved_target" == %* ]] && fail "sidecar persisted an ephemeral pane id '$saved_target' instead of session:window.pane"
print "stable target persisted: $saved_target"

print "saved: claude in pane $claude_pane (pid $claude_pid), sidecar OK"

# --- RESTART: kill the server, losing all ephemeral pane ids ---
$TMUX kill-server 2>/dev/null
sleep 0.5

# Rebuild via resurrect restore (recreates windows/panes with NEW pane ids).
$TMUX new-session -d -s work -c "$SCRATCH" -x 200 -y 50 || fail "rebuild new-session"
$TMUX source-file ~/.tmux.conf 2>/dev/null
$TMUX set-option -g @resurrect-dir "$RESURRECT_DIR"
$TMUX run-shell "$RES/scripts/restore.sh" || fail "resurrect restore.sh failed"
sleep 1

# Sanity: the new server must have assigned a different id set than before.
new_ids=$($TMUX list-panes -a -F '#{pane_id}' | sort | tr '\n' ' ')
print "post-restore pane ids: $new_ids (pre-restore claude pane was $claude_pane)"

# --- RESTORE HOOK: relaunch claude in the restored pane ---
# Swap to the logging fake so we can capture the argv the hook types.
make_restore_fake

# The restore hook sends `command claude --resume` to a restored pane's
# interactive shell. Make the fake claude resolvable there by injecting
# FAKEBIN into each restored pane's PATH at the prompt (after rc files run, so
# it is not clobbered).
while read -r pid; do
  $TMUX send-keys -t "$pid" "export PATH=\"$FAKEBIN:\$PATH\"" C-m
done < <($TMUX list-panes -a -F '#{pane_id}')
sleep 0.3

# SIDECAR_DIR override inlined (run-shell uses the server environment).
$TMUX run-shell "CLAUDE_RESURRECT_SIDECAR_DIR='$SIDECAR_DIR' bash '$RESTORE_HOOK'" \
  || fail "restore hook failed"

# Give the relaunched pane a moment to exec the wrapper.
relaunched=0
for _ in $(seq 1 50); do
  if [[ -r "$RELAUNCH_LOG" ]] && grep -q "$SESSION_ID" "$RELAUNCH_LOG"; then
    relaunched=1; break
  fi
  sleep 0.1
done

if (( ! relaunched )); then
  print "relaunch.log contents: $( [[ -r $RELAUNCH_LOG ]] && cat "$RELAUNCH_LOG" || echo '<none>' )"
  fail "restore hook did NOT relaunch 'claude --resume $SESSION_ID' after server restart"
fi

# Confirm the relaunch carried the exact saved session id (resume, not fresh).
grep -q "RELAUNCHED --resume $SESSION_ID" "$RELAUNCH_LOG" \
  || fail "relaunched without correct --resume <sid>; log: $(cat "$RELAUNCH_LOG")"

# Confirm it landed in the CORRECT pane: the one the stable target resolves to
# in the restored server must now be running our relaunched fake (not a bare
# shell). Other panes had PATH set but received no relaunch, so they stay
# shells - this distinguishes correct targeting from "relaunched somewhere".
resolved_pane=$($TMUX display-message -t "$saved_target" -p '#{pane_id}' 2>/dev/null || true)
[[ -n "$resolved_pane" ]] || fail "stable target '$saved_target' did not resolve to any pane after restore"

targeted_cmd=""
for _ in $(seq 1 50); do
  targeted_cmd=$($TMUX list-panes -a -F '#{pane_id} #{pane_current_command}' | awk -v p="$resolved_pane" '$1==p{print $2}')
  case "$targeted_cmd" in
    bash|zsh|fish|sh|dash|ksh|"") ;;   # still a shell -> relaunch not landed yet
    *) break ;;
  esac
  sleep 0.1
done
case "$targeted_cmd" in
  bash|zsh|fish|sh|dash|ksh|"")
    fail "targeted pane ($saved_target -> $resolved_pane) is still a bare shell ('$targeted_cmd'); relaunch hit the wrong pane" ;;
esac

print "PASS: claude --resume relaunched in the correct restored pane ($saved_target -> $resolved_pane, now '$targeted_cmd') after server restart"
exit 0
