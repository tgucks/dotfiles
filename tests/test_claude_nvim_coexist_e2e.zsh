#!/usr/bin/env zsh
# End-to-end COEXISTENCE test: a single tmux session containing BOTH a claude
# pane and nvim panes is restored correctly after a server restart - claude via
# its sidecar hook (claude --resume <sid>), each nvim via its per-pane session
# (nvim -S <coordfile>). Neither hook interferes with the other, and nvim is NOT
# relaunched by resurrect itself (it is excluded via @resurrect-default-processes).
#
# Topology (tmux session "work"):
#   window 0:
#     0.0  claude pane  (fake claude; restored by save/restore-claude-sessions)
#     0.1  nvim {a.txt, b.txt} vsplit  (restored by restore-nvim-sessions)
#   window 1:
#     1.0  nvim {c.txt}
#
# Isolated: own socket, scratch @resurrect-dir, scratch claude state+sidecar,
# scratch nvim session root_dir. Asserts no leak into the real sessions dir.
#
# Run: zsh tests/test_claude_nvim_coexist_e2e.zsh

emulate -L zsh
set -u

REPO_ROOT="${0:A:h:h}"
SOCKET="coexist-test-$$"
TMUX=(tmux -L "$SOCKET")
NVIM="${NVIM_BIN:-/opt/homebrew/bin/nvim}"
AS_PLUGIN=~/.local/share/nvim/lazy/auto-session
RES=~/.tmux/plugins/tmux-resurrect

SAVE_CLAUDE="$REPO_ROOT/dot_local/share/tmux-dotfiles/executable_save-claude-sessions.sh"
RESTORE_CLAUDE="$REPO_ROOT/dot_local/share/tmux-dotfiles/executable_restore-claude-sessions.sh"
RESTORE_NVIM="$REPO_ROOT/dot_local/share/tmux-dotfiles/executable_restore-nvim-sessions.sh"

for f in "$SAVE_CLAUDE" "$RESTORE_CLAUDE" "$RESTORE_NVIM"; do
  [[ -r "$f" ]] || { print "FAIL: missing $f"; exit 1; }
done
[[ -x "$NVIM" ]] || { print "SKIP: nvim not executable"; exit 0; }
[[ -d "$AS_PLUGIN" ]] || { print "SKIP: auto-session not installed"; exit 0; }
[[ -x "$RES/scripts/save.sh" ]] || { print "SKIP: tmux-resurrect not installed"; exit 0; }

SCRATCH=$(mktemp -d)
RESURRECT_DIR="$SCRATCH/resurrect"
STATE_DIR="$SCRATCH/claude-state"
SIDECAR_DIR="$SCRATCH/claude-sidecar"
SESS_DIR="$SCRATCH/sessions"
FAKEBIN="$SCRATCH/bin"
PROJ="$SCRATCH/proj"
RELAUNCH_LOG="$SCRATCH/relaunch.log"
mkdir -p "$RESURRECT_DIR" "$STATE_DIR" "$SIDECAR_DIR" "$SESS_DIR" "$FAKEBIN" "$PROJ"
print a > "$PROJ/a.txt"; print b > "$PROJ/b.txt"; print c > "$PROJ/c.txt"

SESSION_ID="coexist-sid-$$"
REAL_SESS_DIR="$HOME/.local/share/nvim/sessions"
real_before=$(ls "$REAL_SESS_DIR" 2>/dev/null | sort)

cleanup() {
  $TMUX kill-server 2>/dev/null
  rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$SOCKET" 2>/dev/null
  rm -rf "$SCRATCH"
}
trap cleanup EXIT INT TERM
fail() { print "FAIL: $*"; exit 1; }

# isolated nvim init (scratch root_dir + repo helper + per-pane save autocmds)
cat > "$SCRATCH/init.lua" <<LUA
vim.opt.runtimepath:append(vim.fn.expand("$AS_PLUGIN"))
vim.opt.runtimepath:append(vim.fn.expand("$REPO_ROOT/dot_config/nvim"))
require("auto-session").setup({ auto_restore=false, auto_save=false, root_dir="$SESS_DIR/" })
local ts = require("core.tmux_session")
local function s() require("auto-session").save_session(ts.session_name(), {show_message=false, is_autosave=true}) end
vim.api.nvim_create_user_command("PaneSave", s, {})
vim.api.nvim_create_autocmd({"FocusLost","BufWritePost","CursorHold","VimLeavePre"},
  { group=vim.api.nvim_create_augroup("t",{clear=true}), callback=s })
LUA

# nvim wrapper on PATH -> isolated init
cat > "$FAKEBIN/nvim" <<EOF
#!/bin/sh
exec "$NVIM" -u "$SCRATCH/init.lua" "\$@"
EOF
chmod +x "$FAKEBIN/nvim"

# claude fakes: symlink->sleep for the save phase (comm=claude), logging script
# for the restore phase (captures argv).
make_save_claude()    { rm -f "$FAKEBIN/claude"; ln -s /bin/sleep "$FAKEBIN/claude"; }
make_restore_claude() {
  rm -f "$FAKEBIN/claude"
  cat > "$FAKEBIN/claude" <<EOF
#!/bin/sh
echo "RELAUNCHED \$*" >> "$RELAUNCH_LOG"
exec sleep 300
EOF
  chmod +x "$FAKEBIN/claude"
}
make_save_claude

# --- build topology ---
$TMUX new-session -d -s work -c "$PROJ" -x 220 -y 60 || fail "new-session"
$TMUX source-file ~/.tmux.conf 2>/dev/null
$TMUX set-option -g @resurrect-dir "$RESURRECT_DIR"
$TMUX set-option -g @resurrect-capture-pane-contents 'on'
$TMUX set-option -g @resurrect-default-processes 'vi vim view emacs man less more tail top htop irssi weechat mutt'

# 0.0 claude, 0.1 nvim(a,b)
$TMUX send-keys -t work:0.0 "export PATH=\"$FAKEBIN:\$PATH\"; claude 300" C-m
$TMUX split-window -t work:0 -h -c "$PROJ"
$TMUX send-keys -t work:0.1 "cd '$PROJ' && '$NVIM' -u '$SCRATCH/init.lua' -c 'edit a.txt' -c 'vsplit b.txt' -c 'PaneSave'" C-m
# 1.0 nvim(c)
$TMUX new-window -t work: -c "$PROJ"
$TMUX send-keys -t work:1.0 "cd '$PROJ' && '$NVIM' -u '$SCRATCH/init.lua' -c 'edit c.txt' -c 'PaneSave'" C-m

# wait for claude (ps comm) + both nvim session files
find_claude() {
  ps -eo pid=,ppid=,comm= | awk -v r="$1" '
    {p[$1]=$2;c[$1]=$3} END{n=1;q[1]=r;while(n>0){x=q[n];delete q[n];n--;
      for(k in p)if(p[k]==x){if(c[k]=="claude"){print k;exit};n++;q[n]=k}}}'
}
claude_pane_pid=$($TMUX list-panes -t work:0 -F '#{pane_index} #{pane_pid}' | awk '$1==0{print $2}')
ok=0
for _ in $(seq 1 80); do
  cp=$(find_claude "$claude_pane_pid")
  [[ -n "$cp" && -r "$SESS_DIR/tmux__work__0__1.vim" && -r "$SESS_DIR/tmux__work__1__0.vim" ]] && { ok=1; claude_pid=$cp; break; }
  sleep 0.2
done
(( ok )) || fail "setup incomplete: claude_pid='${cp:-}' sessions=$(ls "$SESS_DIR" 2>/dev/null|tr '\n' ' ')"

# write the claude SessionStart state file (keyed by claude pid)
cat > "$STATE_DIR/claude-$claude_pid.json" <<EOF
{"session_id":"$SESSION_ID","cwd":"$PROJ","pid":$claude_pid,"timestamp":"2026-01-01T00:00:00Z"}
EOF

# --- resurrect save + claude save hook ---
$TMUX run-shell "$RES/scripts/save.sh" || fail "resurrect save failed"
sleep 0.5
$TMUX run-shell "CLAUDE_RESURRECT_STATE_DIR='$STATE_DIR' CLAUDE_RESURRECT_SIDECAR_DIR='$SIDECAR_DIR' bash '$SAVE_CLAUDE'" \
  || fail "claude save hook failed"
sleep 0.3
got=$(jq -r '.sessions[0].session_id // empty' "$SIDECAR_DIR/claude-sessions.json" 2>/dev/null)
[[ "$got" == "$SESSION_ID" ]] || fail "claude sidecar missing session (got '$got')"

# --- restart ---
for p in work:0.1 work:1.0; do $TMUX send-keys -t "$p" ':qa!' C-m 2>/dev/null; done
sleep 1
$TMUX kill-server 2>/dev/null
sleep 0.5
$TMUX new-session -d -s boot -c "$SCRATCH" -x 220 -y 60 || fail "rebuild"
$TMUX source-file ~/.tmux.conf 2>/dev/null
$TMUX set-option -g @resurrect-dir "$RESURRECT_DIR"
$TMUX set-option -g @resurrect-default-processes 'vi vim view emacs man less more tail top htop irssi weechat mutt'
$TMUX run-shell "$RES/scripts/restore.sh" || fail "resurrect restore failed"
sleep 2

# inject fakes into restored panes' PATH, swap claude to logging fake
make_restore_claude
while read -r pid; do
  $TMUX send-keys -t "$pid" "export PATH=\"$FAKEBIN:\$PATH\"" C-m
done < <($TMUX list-panes -a -F '#{pane_id}')
sleep 0.3

# --- run BOTH restore hooks (as the chained post-restore-all would) ---
$TMUX run-shell "CLAUDE_RESURRECT_SIDECAR_DIR='$SIDECAR_DIR' bash '$RESTORE_CLAUDE'; NVIM_RESURRECT_SESSION_DIR='$SESS_DIR' bash '$RESTORE_NVIM'" \
  || fail "restore hooks failed"

# --- assert claude relaunched with correct sid ---
relaunched=0
for _ in $(seq 1 60); do
  [[ -r "$RELAUNCH_LOG" ]] && grep -q "RELAUNCHED --resume $SESSION_ID" "$RELAUNCH_LOG" && { relaunched=1; break; }
  sleep 0.1
done
(( relaunched )) || fail "claude not relaunched with --resume $SESSION_ID; log: $( [[ -r $RELAUNCH_LOG ]] && cat "$RELAUNCH_LOG" || echo none)"

# --- assert both nvim panes came back ---
for p in work:0.1 work:1.0; do
  back=0
  for _ in $(seq 1 60); do
    [[ "$($TMUX display-message -t "$p" -p '#{pane_current_command}' 2>/dev/null)" == nvim ]] && { back=1; break; }
    sleep 0.1
  done
  (( back )) || fail "nvim pane $p did not restore"
done

print "post-restore panes:"
$TMUX list-panes -a -F '   #{session_name}:#{window_index}.#{pane_index} -> #{pane_current_command}'

# --- assert nvim layouts fully restored + no E303 ---
$TMUX send-keys -t work:0.1 ":redir! > $SCRATCH/d01.txt | silent ls | redir END" C-m
$TMUX send-keys -t work:1.0 ":redir! > $SCRATCH/d10.txt | silent ls | redir END" C-m
sleep 0.6
grep -q a.txt "$SCRATCH/d01.txt" && grep -q b.txt "$SCRATCH/d01.txt" || fail "pane 0.1 layout not restored (a,b)"
grep -q c.txt "$SCRATCH/d10.txt" || fail "pane 1.0 layout not restored (c)"
for p in work:0.1 work:1.0; do
  c=$($TMUX capture-pane -p -t "$p" 2>/dev/null || true)
  print -r -- "$c" | grep -qiE 'E303|swap file already exists|ATTENTION' && fail "E303 in $p:\n$c"
done

# --- no real-dir leak ---
ls "$SESS_DIR" | grep -q '%2F' && fail "cwd-keyed session leaked into scratch"
real_after=$(ls "$REAL_SESS_DIR" 2>/dev/null | sort)
[[ "$real_before" == "$real_after" ]] || fail "real sessions dir changed: before=[$real_before] after=[$real_after]"

print "PASS: claude + nvim coexist - claude --resume relaunched, both nvim panes restored full layout, no E303, no leak"
exit 0
