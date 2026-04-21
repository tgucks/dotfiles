-- neotest: unified test runner UI, with Go support via neotest-golang
return {
  "nvim-neotest/neotest",
  dependencies = {
    "nvim-neotest/nvim-nio",
    "nvim-lua/plenary.nvim",
    "antoinemadec/FixCursorHold.nvim",
    "nvim-treesitter/nvim-treesitter",
    {
      "fredrikaverpil/neotest-golang",
      version = "*",
      build = function()
        vim.system({ "go", "install", "gotest.tools/gotestsum@latest" }):wait()
      end,
    },
  },
  keys = {
    {
      "<leader>tf",
      function() require("neotest").run.run(vim.fn.expand("%")) end,
      desc = "Run tests in current file",
    },
    {
      "<leader>ts",
      function() require("neotest").run.run(vim.fn.getcwd()) end,
      desc = "Run whole test suite",
    },
    {
      "<leader>tp",
      function()
        local path = vim.fn.input({
          prompt = "Test path: ",
          default = vim.fn.getcwd() .. "/",
          completion = "file",
        })
        if path ~= "" then require("neotest").run.run(path) end
      end,
      desc = "Run tests in path",
    },
    {
      "<leader>tn",
      function() require("neotest").run.run() end,
      desc = "Run nearest test",
    },
  },
  config = function()
    require("neotest").setup({
      adapters = {
        require("neotest-golang")({
          runner = "gotestsum",
        }),
      },
    })
  end,
}
