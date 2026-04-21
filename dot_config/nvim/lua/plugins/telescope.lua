return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    "nvim-telescope/telescope-live-grep-args.nvim",
  },
  config = function()
    require("telescope").setup({
      defaults = {
        vimgrep_arguments = {
          "rg", "--color=never", "--no-heading", "--with-filename",
          "--line-number", "--column", "--smart-case", "--hidden",
          "--glob", "!.git",
        },
        file_ignore_patterns = { "^%.git/" },
        mappings = {
          i = { ["<Esc>"] = require("telescope.actions").close },
        },
      },
      pickers = {
        find_files = { hidden = true },
      },
      extensions = {
        fzf = {},
      },
    })
    require("telescope").load_extension("fzf")
    require("telescope").load_extension("live_grep_args")
    local builtin = require("telescope.builtin")
    local lga = require("telescope").extensions.live_grep_args
    local lga_shortcuts = require("telescope-live-grep-args.shortcuts")
    vim.keymap.set("n", "<leader>f", builtin.find_files, { desc = "Find files" })
    vim.keymap.set("n", "<leader>r", lga.live_grep_args, { desc = "Live grep (with args)" })
    vim.keymap.set("n", "<leader>R", lga_shortcuts.grep_word_under_cursor, { desc = "Grep word under cursor" })
    vim.keymap.set({ "v", "x" }, "<leader>R", lga_shortcuts.grep_visual_selection, { desc = "Grep visual selection" })
  end,
}
