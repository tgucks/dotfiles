-- Git diff/merge tool
return {
  "sindrets/diffview.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("diffview").setup()
    vim.keymap.set("n", "<leader>gd", "<cmd>DiffviewOpen<CR>",  { desc = "Open diffview" })
    vim.keymap.set("n", "<leader>gD", "<cmd>DiffviewOpen origin/master...HEAD<CR>", { desc = "Diff branch vs origin/master" })
    vim.keymap.set("n", "<leader>gx", "<cmd>DiffviewClose<CR>", { desc = "Close diffview" })
  end,
}
