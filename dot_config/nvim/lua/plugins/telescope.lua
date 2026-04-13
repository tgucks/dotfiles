return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
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
    local builtin = require("telescope.builtin")
    vim.keymap.set("n", "<leader>f",  builtin.find_files,  { desc = "Find files" })
    vim.keymap.set("n", "<leader>r", builtin.live_grep,   { desc = "Live grep" })
    vim.keymap.set("v", "<leader>r", function()
      vim.cmd('noau normal! "vy"')
      local text = vim.fn.getreg("v")
      builtin.live_grep({ default_text = text })
    end, { desc = "Live grep visual selection" })
  end,
}
