return {
  "lewis6991/gitsigns.nvim",
  config = function()
    require("gitsigns").setup()
    vim.keymap.set("n", "<leader>gb", "<cmd>Gitsigns blame<CR>", { desc = "Git blame" })
    vim.keymap.set("n", "]c", "<cmd>Gitsigns next_hunk<CR>", { desc = "Next git hunk" })
    vim.keymap.set("n", "[c", "<cmd>Gitsigns prev_hunk<CR>", { desc = "Prev git hunk" })
  end,
}
