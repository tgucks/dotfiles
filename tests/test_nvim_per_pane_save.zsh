#!/usr/bin/env zsh
# Test: inside a tmux pane, the auto-session autosave writes a PER-PANE session
# file keyed on the stable tmux coordinate (session__window__pane), NOT the
# cwd-keyed file. This is what lets multiple nvim panes in one cwd each keep
# their own layout without colliding.
#
# Drives a real headless nvim inside a real isolated tmux pane, against a
# scratch auto-session root_dir, and asserts the per-pane file appears with all
# buffers - and that NOTHING leaks into the user's real sessions dir.
#
# Run: zsh tests/test_nvim_per_pane_save.zsh

emulate -L zsh
set -u

REPO_ROOT="${0:A:h:h}"
SOCKET="nvim-perpane-test-$$"
TMUX=(tmux -L "$SOCKET")
NVIM="${NVIM_BIN:-/opt/homebrew/bin/nvim}"
AS_PLUGIN=~/.local/share/nvim/lazy/auto-session

if [[ ! -x "$NVIM" ]]; then print "SKIP: $NVIM not executable"; exit 0; fi
if [[ ! -d "$AS_PLUGIN" ]]; then print "SKIP: auto-session not installed"; exit 0; fi

SCRATCH=$(mktemp -d)
SESS_DIR="$SCRATCH/sessions"
PROJ="$SCRATCH/proj"
mkdir -p "$SESS_DIR" "$PROJ"
print "AAA" > "$PROJ/a.txt"
print "BBB" > "$PROJ/b.txt"

REAL_SESS_DIR="$HOME/.local/share/nvim/sessions"
real_before=$(ls "$REAL_SESS_DIR" 2>/dev/null | sort)

cleanup() {
  $TMUX kill-server 2>/dev/null
  rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$SOCKET" 2>/dev/null
  rm -rf "$SCRATCH"
}
trap cleanup EXIT INT TERM
fail() { print "FAIL: $*"; exit 1; }

# Minimal init that loads ONLY the repo's auto-session plugin spec logic we
# care about: the per-pane save helper + autosave wiring. We load the real
# plugin from the lazy install dir, then source the repo's plugin file's
# config by extracting it is overkill - instead we replicate the wiring the
# repo file installs, pointing root_dir at our scratch dir. The helper under
# test lives in the repo as a require()-able module so we load THAT directly.
cat > "$SCRATCH/init.lua" <<LUA
vim.opt.runtimepath:append(vim.fn.expand("$AS_PLUGIN"))
vim.opt.runtimepath:append(vim.fn.expand("$REPO_ROOT/dot_config/nvim"))
require("auto-session").setup({
  auto_restore = false,
  auto_save = false,
  root_dir = "$SESS_DIR/",
})
-- The module under test: returns the per-pane session name for this nvim.
local ok, helper = pcall(require, "core.tmux_session")
if not ok then
  vim.fn.writefile({ "HELPER_MISSING: " .. tostring(helper) }, "$SCRATCH/result.txt")
  vim.cmd("qa!")
  return
end
LUA

# Open two files in a split, then invoke the per-pane save exactly as the
# autocmd will, and record the session name the helper chose.
cat >> "$SCRATCH/init.lua" <<LUA
vim.schedule(function()
  vim.cmd("edit $PROJ/a.txt")
  vim.cmd("vsplit $PROJ/b.txt")
  local name = helper.session_name()
  require("auto-session").save_session(name, { show_message = false, is_autosave = true })
  vim.fn.writefile({ name }, "$SCRATCH/result.txt")
  vim.cmd("qa!")
end)
LUA

# Run headless nvim INSIDE a tmux pane so \$TMUX/\$TMUX_PANE are set and the
# coordinate is real.
$TMUX new-session -d -s work -c "$PROJ" -x 200 -y 50 || fail "new-session"
# window 0 is the shell we drive from; give the pane a known coordinate.
coord_expected="work__0__0"

$TMUX send-keys -t work:0 \
  "NVIM_PERPANE_TEST=1 '$NVIM' --headless -u '$SCRATCH/init.lua'; tmux wait-for -S nvimdone" C-m
$TMUX wait-for nvimdone

[[ -r "$SCRATCH/result.txt" ]] || fail "nvim did not produce result.txt"
result=$(cat "$SCRATCH/result.txt")
case "$result" in
  HELPER_MISSING:*) fail "core.tmux_session helper not found: $result" ;;
esac

print "helper chose session name: $result"
[[ "$result" == "tmux__${coord_expected}" ]] \
  || fail "expected per-pane name 'tmux__${coord_expected}', got '$result'"

# The per-pane session file must exist in scratch (name has only [a-z0-9_] so
# auto-session does not escape it).
sessfile="$SESS_DIR/tmux__${coord_expected}.vim"
[[ -r "$sessfile" ]] || {
  print "scratch sessions dir: $(ls "$SESS_DIR")"
  fail "per-pane session file not written: $sessfile"
}

# It must capture BOTH buffers (full layout, not one file).
grep -q "a.txt" "$sessfile" || fail "session file missing a.txt"
grep -q "b.txt" "$sessfile" || fail "session file missing b.txt"

# It must NOT have written the cwd-keyed file.
cwd_encoded=$(print -r -- "$PROJ" | sed 's/\//%2F/g')
if ls "$SESS_DIR" | grep -q "%2F"; then
  fail "a cwd-keyed session file leaked into scratch: $(ls "$SESS_DIR" | grep %2F)"
fi

# And NOTHING may have leaked into the user's real sessions dir.
real_after=$(ls "$REAL_SESS_DIR" 2>/dev/null | sort)
if [[ "$real_before" != "$real_after" ]]; then
  fail "real sessions dir changed! before=[$real_before] after=[$real_after]"
fi

print "PASS: per-pane session '$result' written with full layout; no cwd file; no real-dir leak"
exit 0
