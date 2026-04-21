return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    preset = "helix",
    delay = 300,
    spec = {
      { "<leader>d", group = "debug" },
      { "<leader>g", group = "git" },
      { "<leader>t", group = "test" },
    },
  },
  keys = {
    {
      "<leader>?",
      function() require("which-key").show({ global = false }) end,
      desc = "Buffer keymaps (which-key)",
    },
  },
}
