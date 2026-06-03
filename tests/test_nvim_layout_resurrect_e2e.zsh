#!/usr/bin/env zsh
# COMPREHENSIVE end-to-end test for the user's hard requirement:
#
#   One tmux session, multiple windows, multiple panes per window (splits),
#   multiple nvim instances sharing ONE cwd, each editing a DIFFERENT multi-file
#   split layout. After a tmux server kill+restart+restore, every nvim pane must
#   come back with its FULL layout (all its buffers), with NO E303 swapfile
#   collision and NO cwd-shared session restore.
#
# Topology built (all inside tmux session "work"):
#   window 0:
#     pane 0.0  shell (control)
#     pane 0.1  nvim editing {a.txt, b.txt} in a vsplit      [cwd = proj]
#     pane 0.2  nvim editing {c.txt}                          [cwd = proj]  (SAME cwd as 0.1)
#   window 1:
#     pane 1.0  nvim editing {d.txt, e.txt, f.txt} (2 splits) [cwd = proj2]
#     pane 1.1  shell
#
# Panes 0.1 and 0.2 share cwd `proj` - the exact E303 danger zone.
#
# Isolated: own tmux socket, scratch @resurrect-dir, scratch auto-session
# root_dir. Asserts ZERO leakage into ~/.local/share/nvim/sessions/.
#
# Run: zsh tests/test_nvim_layout_resurrect_e2e.zsh

emulate -L zsh
set -u

REPO_ROOT="${0:A:h:h}"
SOCKET="nvim-layout-test-$$"
TMUX=(tmux -L "$SOCKET")
NVIM="${NVIM_BIN:-/opt/homebrew/bin/nvim}"
AS_PLUGIN=~/.local/share/nvim/lazy/auto-session
RES=~/.tmux/plugins/tmux-resurrect

RESTORE_NVIM_HOOK="$REPO_ROOT/dot_local/share/tmux-dotfiles/executable_restore-nvim-sessions.sh"

[[ -x "$NVIM" ]] || { print "SKIP: $NVIM not executable"; exit 0; }
[[ -d "$AS_PLUGIN" ]] || { print "SKIP: auto-session not installed"; exit 0; }
[[ -x "$RES/scripts/save.sh" ]] || { print "SKIP: tmux-resurrect not installed"; exit 0; }
[[ -r "$RESTORE_NVIM_HOOK" ]] || { print "FAIL: missing $RESTORE_NVIM_HOOK"; exit 1; }

SCRATCH=$(mktemp -d)
RESURRECT_DIR="$SCRATCH/resurrect"
SESS_DIR="$SCRATCH/sessions"
PROJ="$SCRATCH/proj"
PROJ2="$SCRATCH/proj2"
mkdir -p "$RESURRECT_DIR" "$SESS_DIR" "$PROJ" "$PROJ2"
for f in a b c; do print "$f content" > "$PROJ/$f.txt"; done
for f in d e f; do print "$f content" > "$PROJ2/$f.txt"; done

REAL_SESS_DIR="$HOME/.local/share/nvim/sessions"
real_before=$(ls "$REAL_SESS_DIR" 2>/dev/null | sort)

cleanup() {
  $TMUX kill-server 2>/dev/null
  rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$SOCKET" 2>/dev/null
  rm -rf "$SCRATCH"
}
trap cleanup EXIT INT TERM
fail() { print "FAIL: $*"; exit 1; }

# init.lua used by every nvim instance: loads auto-session with our scratch
# root_dir + the repo helper, and wires the SAME per-pane autosave the real
# config uses (so a restored nvim re-saves to its per-pane file, never the cwd
# file). We also expose PaneSave to trigger an explicit save deterministically.
cat > "$SCRATCH/init.lua" <<LUA
vim.opt.runtimepath:append(vim.fn.expand("$AS_PLUGIN"))
vim.opt.runtimepath:append(vim.fn.expand("$REPO_ROOT/dot_config/nvim"))
require("auto-session").setup({ auto_restore = false, auto_save = false, root_dir = "$SESS_DIR/" })
local tmux_session = require("core.tmux_session")
local function save_session()
  require("auto-session").save_session(tmux_session.session_name(), { show_message = false, is_autosave = true })
end
vim.api.nvim_create_user_command("PaneSave", save_session, {})
-- Mirror the repo's safety-save autocmds so a RESTORED nvim keeps writing its
-- own per-pane file (and never a cwd file) - this is what the real config does.
vim.api.nvim_create_autocmd({ "FocusLost", "BufWritePost", "CursorHold", "VimLeavePre" }, {
  group = vim.api.nvim_create_augroup("test_perpane_save", { clear = true }),
  callback = save_session,
})
LUA

# A scratch \`nvim\` on PATH that injects our isolated init. The restore hook
# sends a bare \`command nvim -S <file>\`; this wrapper makes that resolve to an
# nvim that uses the scratch root_dir, so the test never touches the real
# config or the real sessions dir. (\`command\` bypasses shell functions/aliases
# but still honors PATH, so the wrapper is picked up.)
FAKEBIN="$SCRATCH/bin"
mkdir -p "$FAKEBIN"
cat > "$FAKEBIN/nvim" <<EOF
#!/bin/sh
exec "$NVIM" -u "$SCRATCH/init.lua" "\$@"
EOF
chmod +x "$FAKEBIN/nvim"

# Helper: open files in a pane's nvim and save its per-pane session.
# $1=pane target, $2=cwd, $3..=vim open commands
open_nvim_and_save() {
  local pane="$1" cwd="$2"; shift 2
  local cmds=""
  local c
  for c in "$@"; do cmds+=" -c \"$c\""; done
  $TMUX send-keys -t "$pane" \
    "cd '$cwd' && '$NVIM' -u '$SCRATCH/init.lua'${cmds} -c 'PaneSave'" C-m
}

# --- build the topology ---
$TMUX new-session -d -s work -c "$PROJ" -x 220 -y 60 || fail "new-session"
$TMUX source-file ~/.tmux.conf 2>/dev/null
$TMUX set-option -g @resurrect-dir "$RESURRECT_DIR"
$TMUX set-option -g @resurrect-capture-pane-contents 'on'
# match production: nvim excluded from resurrect's own relaunch
$TMUX set-option -g @resurrect-default-processes 'vi vim view emacs man less more tail top htop irssi weechat mutt'

# window 0: shell + two nvim panes sharing cwd PROJ
$TMUX split-window -t work:0 -h -c "$PROJ"   # creates 0.1
$TMUX split-window -t work:0.1 -v -c "$PROJ" # creates 0.2
# window 1: one nvim pane (proj2) + a shell
$TMUX new-window -t work: -c "$PROJ2"        # window 1, pane 0
$TMUX split-window -t work:1 -h -c "$PROJ2"  # 1.1 shell

# Launch nvim in the three nvim panes with distinct layouts.
open_nvim_and_save work:0.1 "$PROJ"  "edit a.txt" "vsplit b.txt"
open_nvim_and_save work:0.2 "$PROJ"  "edit c.txt"
open_nvim_and_save work:1.0 "$PROJ2" "edit d.txt" "vsplit e.txt" "split f.txt"

# Wait until all three per-pane session files are written.
expected_sessions=(tmux__work__0__1 tmux__work__0__2 tmux__work__1__0)
ok=0
for _ in $(seq 1 80); do
  have=1
  for s in $expected_sessions; do
    [[ -r "$SESS_DIR/$s.vim" ]] || { have=0; break; }
  done
  (( have )) && { ok=1; break; }
  sleep 0.2
done
(( ok )) || {
  print "sessions present: $(ls "$SESS_DIR" 2>/dev/null)"
  fail "not all per-pane session files were written before save"
}
print "per-pane sessions saved: $(ls "$SESS_DIR" | tr '\n' ' ')"

# Assert no cwd-shared session leaked (would contain %2F path encoding).
if ls "$SESS_DIR" | grep -q '%2F'; then
  fail "a cwd-keyed session leaked: $(ls "$SESS_DIR" | grep %2F)"
fi

# Each session must hold its full buffer set.
grep -q 'a.txt' "$SESS_DIR/tmux__work__0__1.vim" && grep -q 'b.txt' "$SESS_DIR/tmux__work__0__1.vim" \
  || fail "pane 0.1 session missing a/b"
grep -q 'c.txt' "$SESS_DIR/tmux__work__0__2.vim" || fail "pane 0.2 session missing c"
for f in d e f; do
  grep -q "$f.txt" "$SESS_DIR/tmux__work__1__0.vim" || fail "pane 1.0 session missing $f"
done

# --- resurrect save, then quit all nvim, kill server ---
$TMUX run-shell "$RES/scripts/save.sh" || fail "resurrect save failed"
sleep 0.5
for p in work:0.1 work:0.2 work:1.0; do
  $TMUX send-keys -t "$p" ':qa!' C-m 2>/dev/null
done
sleep 1
$TMUX kill-server 2>/dev/null
sleep 0.5

# --- restart with non-colliding bootstrap session, restore ---
$TMUX new-session -d -s boot -c "$SCRATCH" -x 220 -y 60 || fail "rebuild new-session"
$TMUX source-file ~/.tmux.conf 2>/dev/null
$TMUX set-option -g @resurrect-dir "$RESURRECT_DIR"
$TMUX set-option -g @resurrect-default-processes 'vi vim view emacs man less more tail top htop irssi weechat mutt'
$TMUX run-shell "$RES/scripts/restore.sh" || fail "resurrect restore failed"
sleep 2

# Inject the scratch nvim wrapper into each restored pane's PATH (at the prompt,
# after rc files) so the hook's `command nvim -S` uses the isolated config.
while read -r pid; do
  $TMUX send-keys -t "$pid" "export PATH=\"$FAKEBIN:\$PATH\"" C-m
done < <($TMUX list-panes -a -F '#{pane_id}')
sleep 0.3

# Run the nvim restore hook against our scratch session dir.
$TMUX run-shell "NVIM_RESURRECT_SESSION_DIR='$SESS_DIR' bash '$RESTORE_NVIM_HOOK'" \
  || fail "nvim restore hook failed"

# Wait for the three nvim panes to come back (by stable coordinate).
nvim_panes=(work:0.1 work:0.2 work:1.0)
for _ in $(seq 1 80); do
  back=1
  for p in $nvim_panes; do
    cmd=$($TMUX display-message -t "$p" -p '#{pane_current_command}' 2>/dev/null || true)
    [[ "$cmd" == nvim ]] || { back=0; break; }
  done
  (( back )) && break
  sleep 0.2
done

print "post-restore panes:"
$TMUX list-panes -a -F '   #{session_name}:#{window_index}.#{pane_index} -> #{pane_current_command}'

for p in $nvim_panes; do
  cmd=$($TMUX display-message -t "$p" -p '#{pane_current_command}' 2>/dev/null || true)
  [[ "$cmd" == nvim ]] || fail "pane $p did not come back as nvim (got '$cmd')"
done

# --- verify each restored nvim has its FULL buffer set, and NO E303 anywhere ---
# Drive each restored nvim to dump its buffer list to a file via tmux send-keys.
dump_buffers() {
  local pane="$1" out="$2"
  $TMUX send-keys -t "$pane" "" C-m  # ensure prompt settled (no-op in nvim)
  # In nvim: write the ls output to $out, but do NOT quit (leave it running).
  $TMUX send-keys -t "$pane" ":redir! > $out | silent ls | redir END" C-m
  sleep 0.4
}
dump_buffers work:0.1 "$SCRATCH/r_0_1.txt"
dump_buffers work:0.2 "$SCRATCH/r_0_2.txt"
dump_buffers work:1.0 "$SCRATCH/r_1_0.txt"
sleep 0.5

check_buffers() {
  local out="$1"; shift
  [[ -r "$out" ]] || fail "no buffer dump at $out (nvim may not have restored)"
  local f
  for f in "$@"; do
    grep -q "$f" "$out" || {
      print "dump $out: $(tr '\n' '|' < "$out")"
      fail "restored nvim missing buffer $f (layout not fully restored)"
    }
  done
}
check_buffers "$SCRATCH/r_0_1.txt" a.txt b.txt
check_buffers "$SCRATCH/r_0_2.txt" c.txt
check_buffers "$SCRATCH/r_1_0.txt" d.txt e.txt f.txt

# E303 / swapfile collision check: scan all restored panes' visible content.
for p in $nvim_panes work:0.0; do
  content=$($TMUX capture-pane -p -t "$p" 2>/dev/null || true)
  if print -r -- "$content" | grep -qiE 'E303|swap file already exists|ATTENTION'; then
    fail "E303/swapfile collision detected in pane $p:\n$content"
  fi
done

# No cwd-shared file may have appeared during restore either.
ls "$SESS_DIR" | grep -q '%2F' && fail "cwd-keyed session appeared during restore"

# Zero leakage into the real sessions dir.
real_after=$(ls "$REAL_SESS_DIR" 2>/dev/null | sort)
[[ "$real_before" == "$real_after" ]] \
  || fail "real sessions dir changed! before=[$real_before] after=[$real_after]"

print "PASS: 3 nvim panes (2 sharing one cwd) restored full layouts after restart; no E303; no cwd-shared session; no real-dir leak"
exit 0
