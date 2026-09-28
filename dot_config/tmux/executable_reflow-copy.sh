#!/bin/sh
# Rejoin lines that a TUI hard-wrapped at the pane edge, strip the shared
# indent, and send the result to the tmux buffer + system clipboard.
# A line counts as wrapped when the next line's first word would not have
# fit after it within the pane width.
# Usage: reflow-copy.sh WIDTH < selection

width=${1:-$(tmux display -p '#{pane_width}')}

awk -v width="$width" '
{ lines[NR] = $0 }
END {
  min = -1
  for (i = 1; i <= NR; i++) {
    if (lines[i] ~ /^[ \t]*$/) continue
    match(lines[i], /^ */)
    if (min < 0 || RLENGTH < min) min = RLENGTH
  }
  if (min < 0) min = 0

  out = ""; prev = ""; prevraw = ""; have = 0
  for (i = 1; i <= NR; i++) {
    raw = lines[i]
    sub(/[ \t]+$/, "", raw)
    line = substr(raw, min + 1)
    if (have && prev != "" && line != "") {
      body = line
      sub(/^ +/, "", body)
      split(body, w, " ")
      if (body !~ /^([-*+>]|[0-9]+[.)]) / && length(prevraw) + 1 + length(w[1]) > width - 2) {
        prev = prev " " body
        prevraw = raw
        continue
      }
    }
    if (have) out = out prev "\n"
    prev = line; prevraw = raw; have = 1
  }
  if (have) out = out prev
  printf "%s", out
}' | tmux load-buffer -w -
