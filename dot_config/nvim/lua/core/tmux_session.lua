-- Per-pane tmux session identity for auto-session.
--
-- auto-session normally keys session files by cwd, so multiple nvim instances
-- in one directory share a single file and collide on restore. To let each
-- tmux pane keep its own layout, we key the session on the pane's STABLE tmux
-- coordinate (session__window__pane) - the same identity tmux-resurrect
-- rebuilds after a server restart. The matching restore hook
-- (restore-nvim-sessions.sh) relaunches `nvim -S <this file>` per pane.
--
-- The coordinate uses only [A-Za-z0-9_] separators so auto-session's
-- percent-encoding leaves the name untouched, and the bash restore hook can
-- reconstruct the identical filename without reimplementing the escaping.

local M = {}

-- True when nvim is running inside tmux.
function M.in_tmux()
  return (vim.env.TMUX ~= nil and vim.env.TMUX ~= "")
    and (vim.env.TMUX_PANE ~= nil and vim.env.TMUX_PANE ~= "")
end

-- Sanitize a tmux session name to the [A-Za-z0-9_] alphabet so the resulting
-- auto-session name is not percent-encoded (keeps Lua save side and bash
-- restore side in agreement). Any other char becomes '-'.
local function sanitize(s)
  return (tostring(s):gsub("[^%w_]", "-"))
end

-- The pane coordinate "<session>__<window>__<pane>" for the current pane, or
-- nil when not in tmux or the query fails.
function M.coordinate()
  if not M.in_tmux() then
    return nil
  end
  local fmt = "#{session_name}\t#{window_index}\t#{pane_index}"
  local out = vim.fn.system({
    "tmux", "display-message", "-p", "-t", vim.env.TMUX_PANE, fmt,
  })
  if vim.v.shell_error ~= 0 or not out or out == "" then
    return nil
  end
  local session, window, pane = out:match("^(.-)\t(%d+)\t(%d+)")
  if not session then
    return nil
  end
  return string.format("%s__%s__%s", sanitize(session), window, pane)
end

-- The per-pane auto-session name ("tmux__<coord>") for the current pane, or
-- nil when not in tmux (caller falls back to the cwd-keyed default).
function M.session_name()
  local coord = M.coordinate()
  if not coord then
    return nil
  end
  return "tmux__" .. coord
end

return M
