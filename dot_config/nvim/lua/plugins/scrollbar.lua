-- Scrollbar with git and diagnostic markers, shown only in the active window
return {
  "petertriho/nvim-scrollbar",
  dependencies = { "lewis6991/gitsigns.nvim", "catppuccin/nvim" },
  config = function()
    local colors = require("catppuccin.palettes").get_palette("macchiato")
    require("scrollbar").setup({
      -- Plugin wires a `clear` augroup on these events when show_in_active_only is true.
      -- BufLeave is added on top of the defaults because BufWinLeave is suppressed when a
      -- buffer is still visible in another window. After `:vs` both panes share a buffer,
      -- so `:e otherfile` in the active pane never fires BufWinLeave for the original
      -- buffer and its extmarks linger on the inactive pane. BufLeave fires unconditionally
      -- on buffer switch and flushes those stale marks.
      show_in_active_only = true,
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
          "BufLeave",
          "BufWinLeave",
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
  end,
}
