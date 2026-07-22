return {
  "mrjones2014/smart-splits.nvim",
  lazy = false,
  opts = {
    ignored_filetypes = { "NvimTree" },
  },
  keys = {
    { "<c-h>", function() require("smart-splits").move_cursor_left() end, desc = "Move to left split" },
    { "<c-j>", function() require("smart-splits").move_cursor_down() end, desc = "Move to below split" },
    { "<c-k>", function() require("smart-splits").move_cursor_up() end, desc = "Move to above split" },
    { "<c-l>", function() require("smart-splits").move_cursor_right() end, desc = "Move to right split" },
    { "<c-\\>", function() require("smart-splits").move_cursor_previous() end, desc = "Move to previous split" },
    { "<M-h>", function() require("smart-splits").resize_left() end, desc = "Resize split left" },
    { "<M-j>", function() require("smart-splits").resize_down() end, desc = "Resize split down" },
    { "<M-k>", function() require("smart-splits").resize_up() end, desc = "Resize split up" },
    { "<M-l>", function() require("smart-splits").resize_right() end, desc = "Resize split right" },
  },
}
