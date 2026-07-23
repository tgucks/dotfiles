-- neotest: unified test runner UI, with Go support via neotest-golang and
-- JS/TS support via neotest-vitest
return {
  "nvim-neotest/neotest",
  dependencies = {
    "nvim-neotest/nvim-nio",
    "nvim-lua/plenary.nvim",
    "antoinemadec/FixCursorHold.nvim",
    "nvim-treesitter/nvim-treesitter",
    "marilari88/neotest-vitest",
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
      function()
        vim.notify("Running tests in file...", vim.log.levels.INFO, { title = "neotest" })
        require("neotest").run.run(vim.fn.expand("%"))
      end,
      desc = "Run tests in current file",
    },
    {
      "<leader>ts",
      function()
        vim.notify("Running whole test suite...", vim.log.levels.INFO, { title = "neotest" })
        require("neotest").run.run(vim.fn.getcwd())
      end,
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
        if path ~= "" then
          vim.notify("Running tests in " .. vim.fn.fnamemodify(path, ":~:."), vim.log.levels.INFO, { title = "neotest" })
          require("neotest").run.run(path)
        end
      end,
      desc = "Run tests in path",
    },
    {
      "<leader>tn",
      function()
        vim.notify("Running nearest test...", vim.log.levels.INFO, { title = "neotest" })
        require("neotest").run.run()
      end,
      desc = "Run nearest test",
    },
  },
  config = function()
    require("neotest").setup({
      adapters = {
        require("neotest-golang")({
          runner = "gotestsum",
        }),
        require("neotest-vitest")({
          filter_dir = function(name) return name ~= "node_modules" end,
        }),
      },
      floating = {
        border = "rounded",
        options = { winblend = 0 },
      },
      status = {
        enabled = true,
        signs = true,
        virtual_text = true,
      },
      output = {
        enabled = true,
        open_on_run = "short",
      },
      quickfix = {
        enabled = true,
        open = false,
      },
    })
  end,
}
