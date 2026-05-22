#!/usr/bin/env zsh
# Integration test: the reaper kills a real orphan nvim --embed.
#
# Spawns an nvim --embed orphan (parent dies, kernel reparents to PID 1, stdin
# held open by a detached writer so nvim doesn't EOF-exit on its own), then
# invokes the reaper and asserts the orphan is gone.
#
# Run: zsh tests/test_nvim_reaper_integration.zsh

emulate -L zsh
set -u

ALIASES_FILE="${ZSH_ALIASES:-$HOME/.zsh_aliases}"
NVIM_BIN="${NVIM_BIN:-/opt/homebrew/bin/nvim}"

if [[ ! -x "$NVIM_BIN" ]]; then
  print "SKIP: $NVIM_BIN not executable"
  exit 0
fi

add-zsh-hook() { :; }
source "$ALIASES_FILE"

pidfile=$(mktemp)
fifo=$(mktemp -u).fifo
mkfifo "$fifo"

cleanup() {
  if [[ -f "$pidfile" ]]; then
    pid=$(cat "$pidfile" 2>/dev/null)
    [[ -n "$pid" ]] && kill -9 "$pid" 2>/dev/null
  fi
  [[ -n "${holder:-}" ]] && kill -9 "$holder" 2>/dev/null
  rm -f "$pidfile" "$fifo"
}
trap cleanup EXIT INT TERM

# Holder: keep fifo's write end open so nvim's stdin never EOFs
nohup sleep 60 > "$fifo" </dev/null 2>/dev/null &
holder=$!
disown $holder 2>/dev/null

# Spawn orphan: subshell exits, kernel reparents nvim to PID 1
( "$NVIM_BIN" --embed <"$fifo" >/dev/null 2>&1 & echo $! > "$pidfile" )

sleep 1
embed_pid=$(cat "$pidfile")

if ! ps -p "$embed_pid" >/dev/null 2>&1; then
  print "FAIL: embed exited unexpectedly during setup"
  exit 1
fi

ppid=$(ps -o ppid= -p "$embed_pid" 2>/dev/null | tr -d ' ')
if [[ "$ppid" != "1" ]]; then
  print "FAIL: setup expected PPID=1, got $ppid"
  exit 1
fi

print "spawned orphan: pid=$embed_pid ppid=$ppid; running reaper with grace=0"

NVIM_REAPER_GRACE=0 _nvim_reap_orphans

# Give the kill a moment
sleep 1

if ps -p "$embed_pid" >/dev/null 2>&1; then
  print "FAIL: reaper did not kill orphan (pid=$embed_pid still alive)"
  exit 1
fi

print "PASS: synchronous reaper killed orphan within 1s"

# --- Async wrapper test ---------------------------------------------------
# The precmd hook calls the async wrapper, which must reap orphans without
# blocking the prompt. Spawn a fresh orphan and verify the wrapper still
# reaps it (allowing a short window for the background subshell to finish).

nohup sleep 60 > "$fifo" </dev/null 2>/dev/null &
holder=$!
disown $holder 2>/dev/null

( "$NVIM_BIN" --embed <"$fifo" >/dev/null 2>&1 & echo $! > "$pidfile" )
sleep 1
embed_pid=$(cat "$pidfile")

ppid=$(ps -o ppid= -p "$embed_pid" 2>/dev/null | tr -d ' ')
if [[ "$ppid" != "1" ]]; then
  print "FAIL: async setup expected PPID=1, got $ppid"
  exit 1
fi

print "spawned orphan: pid=$embed_pid; calling async wrapper"

NVIM_REAPER_GRACE=0 _nvim_reap_orphans_async

# Async means we have to poll for completion. Give it up to 5s.
deadline=$(( $(date +%s) + 5 ))
while (( $(date +%s) < deadline )); do
  ps -p "$embed_pid" >/dev/null 2>&1 || break
  sleep 0.1
done

if ps -p "$embed_pid" >/dev/null 2>&1; then
  print "FAIL: async wrapper did not kill orphan within 5s"
  exit 1
fi

print "PASS: async wrapper killed orphan"
exit 0
