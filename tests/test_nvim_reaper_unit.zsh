#!/usr/bin/env zsh
# Unit tests for the nvim --embed orphan reaper helpers in ~/.zsh_aliases.
#
# Run: zsh tests/test_nvim_reaper_unit.zsh
# Exit 0 = pass, exit 1 = fail.
#
# Tests source the deployed ~/.zsh_aliases (run `chezmoi apply` first if
# you've edited the source).

emulate -L zsh
set -u

ALIASES_FILE="${ZSH_ALIASES:-$HOME/.zsh_aliases}"

if [[ ! -f "$ALIASES_FILE" ]]; then
  print "FAIL: $ALIASES_FILE not found (did you run \`chezmoi apply\`?)"
  exit 1
fi

# Source the helpers. We don't want the file's `add-zsh-hook` calls to register
# real precmd hooks in this test process, so we shadow add-zsh-hook to a noop.
add-zsh-hook() { :; }
source "$ALIASES_FILE"

failures=0
ok()   { print "ok    $1" }
fail() { print "FAIL  $1: $2"; (( failures++ )) }

# --- _nvim_etime_to_seconds ---
test_etime() {
  local input="$1" expected="$2"
  local actual
  actual=$(_nvim_etime_to_seconds "$input")
  if [[ "$actual" == "$expected" ]]; then
    ok "etime '$input' -> $expected"
  else
    fail "etime '$input'" "got '$actual', want '$expected'"
  fi
}

test_etime "00:30"      "30"      # 30 seconds
test_etime "01:30"      "90"      # 1m 30s
test_etime "10:00"      "600"     # 10 minutes
test_etime "01:30:45"   "5445"    # 1h 30m 45s
test_etime "1-02:00:00" "93600"   # 1 day 2 hours
test_etime "00:00"      "0"
# Leading zeros must not trigger octal (08, 09 would error in arithmetic)
test_etime "00:09"      "9"
test_etime "00:08:09"   "489"

# --- _nvim_should_reap (pure predicate) ---
test_reap() {
  local ppid="$1" etime_secs="$2" grace="$3" expected_rc="$4" name="$5"
  _nvim_should_reap "$ppid" "$etime_secs" "$grace"
  local rc=$?
  if [[ "$rc" == "$expected_rc" ]]; then
    ok "$name"
  else
    fail "$name" "got rc=$rc, want $expected_rc"
  fi
}

# Reap conditions: PPID must be 1 AND etime must meet/exceed grace
test_reap "1"     "120"  "60"  "0"  "orphan past grace -> reap"
test_reap "1"     "60"   "60"  "0"  "orphan at grace -> reap"
test_reap "1"     "10"   "60"  "1"  "orphan within grace -> spare"
test_reap "30368" "1000" "60"  "1"  "live parent -> spare"
test_reap "1"     "0"    "0"   "0"  "grace=0 reaps any orphan"
test_reap "0"     "120"  "60"  "1"  "ppid=0 (kernel proc) -> spare"

if (( failures > 0 )); then
  print ""
  print "$failures test(s) failed"
  exit 1
fi
print ""
print "all tests passed"
