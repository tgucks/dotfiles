-- Scrollbar with git and diagnostic markers, shown only in the active window.
--
-- The plugin ships `show_in_active_only`, which wires its own clear autocmd
-- on leave events. That handles the common flow (enter a window, the previous
-- window fires WinLeave, plugin clears it) but misses these cases:
--
-- 1. :vsplit copies the current window without firing WinLeave on any other
--    pane, so a formerly-inactive pane can retain stale marks indefinitely.
-- 2. Plugins that shuffle windows (nvim-tree, telescope) sometimes trigger
--    transient WinEnter/BufEnter on buffers that become "current" for a
--    frame, causing render into panes that are not the final active one.
-- 3. BufWinLeave on window close fires *after* focus has moved; the plugin's
--    clear runs against the new active buffer and nukes its freshly-rendered
--    marks.
--
-- The supplemental autocmd below uses the plugin's public `scrollbar.clear`
-- API but calls it scoped to each non-active window via `nvim_win_call`.
-- This runs on *enter* (not leave) so it always has the correct "one active
-- window" invariant regardless of how we got there.
return {
  "petertriho/nvim-scrollbar",
  dependencies = { "lewis6991/gitsigns.nvim", "catppuccin/nvim" },
  config = function()
    local colors = require("catppuccin.palettes").get_palette("macchiato")
    local scrollbar = require("scrollbar")

    scrollbar.setup({
      show_in_active_only = true,
      -- Override the clear event list to drop BufWinLeave. Default list includes
      -- BufWinLeave, which fires AFTER focus has moved when a window closes
      -- (e.g. closing nvim-tree). The plugin's clear targets the current
      -- buffer, so it wipes the freshly-focused pane's marks by mistake.
      -- WinLeave on the closing window already handles the legitimate cleanup.
      autocmd = {
        render = {
          "BufWinEnter",
          "TabEnter",
          "TermEnter",
          "WinEnter",
          "CmdwinLeave",
          "TextChanged",
          "VimResized",
          "WinScrolled",
        },
        clear = {
          "TabLeave",
          "TermLeave",
          "WinLeave",
        },
      },
      handle = {
        blend = 30,
        color = colors.surface2,
      },
      marks = {
        GitAdd    = { color = colors.green },
        GitChange = { color = colors.yellow },
        GitDelete = { color = colors.red },
      },
      excluded_filetypes = { "NvimTree", "neo-tree", "lazy", "mason" },
    })
    require("scrollbar.handlers.gitsigns").setup()

    -- Find the scrollbar namespace once; the plugin creates it at setup time.
    local scrollbar_ns
    for name, ns in pairs(vim.api.nvim_get_namespaces()) do
      if name == "Scrollbar" then scrollbar_ns = ns; break end
    end

    local function reconcile()
      if not scrollbar_ns then return end
      local active = vim.api.nvim_get_current_win()
      -- Clear stale marks from every inactive window. Needed because :vsplit
      -- and plugin-driven window shuffles don't always fire a matching leave
      -- event for the formerly-inactive pane.
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if win ~= active and vim.api.nvim_win_is_valid(win) then
          local buf = vim.api.nvim_win_get_buf(win)
          vim.api.nvim_buf_clear_namespace(buf, scrollbar_ns, 0, -1)
        end
      end
      -- Re-render the active window. After a tree/popup close, earlier clear
      -- events may have wiped the active pane; the plugin's own render may
      -- not re-fire if the relevant enter events already ran.
      if vim.api.nvim_win_is_valid(active) then
        vim.api.nvim_win_call(active, function() scrollbar.render() end)
      end
    end

    local group = vim.api.nvim_create_augroup("ScrollbarActiveOnly", { clear = true })
    vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter", "WinNew", "WinClosed", "CmdwinLeave" }, {
      group = group,
      callback = function() vim.schedule(reconcile) end,
    })
  end,
}
