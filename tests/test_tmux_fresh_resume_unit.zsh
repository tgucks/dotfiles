#!/usr/bin/env zsh
# Unit tests for the tmux() fresh-vs-resume wrapper in ~/.zsh_aliases.
#
# Verifies the wrapper's halt-file toggling and new-session/attach
# delegation logic using a fake `tmux` binary on PATH, so no real tmux
# server is started. Continuum's own behavior when it sees the halt file
# is tmux-continuum's code, not ours, so it isn't exercised here — see
# docs/superpowers/specs/2026-07-07-tmux-fresh-vs-resume-design.md for the
# manual end-to-end checklist that covers that.
#
# Run: zsh tests/test_tmux_fresh_resume_unit.zsh

emulate -L zsh
set -u

ALIASES_FILE="${ZSH_ALIASES:-$HOME/.zsh_aliases}"

if [[ ! -f "$ALIASES_FILE" ]]; then
  print "FAIL: $ALIASES_FILE not found (did you run \`chezmoi apply\`?)"
  exit 1
fi

add-zsh-hook() { :; }
source "$ALIASES_FILE"

if ! typeset -f tmux >/dev/null; then
  print "FAIL: tmux() function not defined after sourcing $ALIASES_FILE"
  exit 1
fi

SCRATCH=$(mktemp -d)
FAKEBIN="$SCRATCH/bin"
mkdir -p "$FAKEBIN"
export TMUX_STUB_LOG="$SCRATCH/log"
touch "$TMUX_STUB_LOG"

cat > "$FAKEBIN/tmux" <<'STUB'
#!/bin/sh
printf 'ARGS:[%s]\n' "$*" >> "$TMUX_STUB_LOG"
case "$1" in
  has-session) exit "${TMUX_STUB_HAS_SESSION_RC:-1}" ;;
  *) exit 0 ;;
esac
STUB
chmod +x "$FAKEBIN/tmux"
export PATH="$FAKEBIN:$PATH"

HALT_FILE="$HOME/tmux_no_auto_restore"
halt_existed=0
[[ -e "$HALT_FILE" ]] && halt_existed=1
halt_backup="$SCRATCH/halt_backup"
(( halt_existed )) && cp "$HALT_FILE" "$halt_backup"

cleanup() {
  rm -f "$HALT_FILE"
  (( halt_existed )) && cp "$halt_backup" "$HALT_FILE"
  rm -rf "$SCRATCH"
}
trap cleanup EXIT INT TERM

failures=0
ok()   { print "ok    $1" }
fail() { print "FAIL  $1: $2"; (( failures++ )) }

reset_log() { : > "$TMUX_STUB_LOG" }
last_call()  { tail -n 1 "$TMUX_STUB_LOG" }

# --- Case 1: bare `tmux`, halt file absent -> created, plain delegate ---
rm -f "$HALT_FILE"
reset_log
tmux
if [[ -e "$HALT_FILE" ]]; then ok "bare tmux creates halt file"; else fail "bare tmux creates halt file" "missing"; fi
call=$(last_call)
[[ "$call" == "ARGS:[]" ]] && ok "bare tmux delegates with no args" || fail "bare tmux delegates with no args" "got '$call'"

# --- Case 2: `tmux new -s foo`, halt file absent -> created, args passed through ---
rm -f "$HALT_FILE"
reset_log
tmux new -s foo
if [[ -e "$HALT_FILE" ]]; then ok "tmux new -s foo creates halt file"; else fail "tmux new -s foo creates halt file" "missing"; fi
call=$(last_call)
[[ "$call" == "ARGS:[new -s foo]" ]] && ok "tmux new -s foo passes args through" || fail "tmux new -s foo passes args through" "got '$call'"

# --- Case 3: `tmux --resume`, no server (has-session fails) -> halt file removed, plain delegate ---
touch "$HALT_FILE"
reset_log
TMUX_STUB_HAS_SESSION_RC=1 tmux --resume
if [[ ! -e "$HALT_FILE" ]]; then ok "--resume with no server clears halt file"; else fail "--resume with no server clears halt file" "still present"; fi
call=$(last_call)
[[ "$call" == "ARGS:[]" ]] && ok "--resume with no server delegates plain" || fail "--resume with no server delegates plain" "got '$call'"

# --- Case 4: `tmux --resume`, server running (has-session succeeds) -> attach, halt file untouched ---
rm -f "$HALT_FILE"
reset_log
TMUX_STUB_HAS_SESSION_RC=0 tmux --resume
if [[ ! -e "$HALT_FILE" ]]; then ok "--resume with server running leaves halt file untouched"; else fail "--resume with server running leaves halt file untouched" "was created"; fi
call=$(last_call)
[[ "$call" == "ARGS:[attach]" ]] && ok "--resume with server running calls attach" || fail "--resume with server running calls attach" "got '$call'"

# --- Case 5: `tmux --resume -t foo`, server running -> attach -t foo, extra args pass through ---
reset_log
TMUX_STUB_HAS_SESSION_RC=0 tmux --resume -t foo
call=$(last_call)
[[ "$call" == "ARGS:[attach -t foo]" ]] && ok "--resume -t foo passes remaining args to attach" || fail "--resume -t foo passes remaining args to attach" "got '$call'"

if (( failures > 0 )); then
  print ""
  print "$failures test(s) failed"
  exit 1
fi
print ""
print "all tests passed"
