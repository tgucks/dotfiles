-- Format JS/TS/JSON on save with the project's local prettier (node_modules/.bin).
-- No LSP fallback: ts_ls doesn't format meaningfully, and the eslint fix-all
-- autocmd in lsp.lua already covers lint-driven fixes.
return {
  "stevearc/conform.nvim",
  event = "BufWritePre",
  opts = {
    formatters_by_ft = {
      javascript = { "prettier" },
      javascriptreact = { "prettier" },
      typescript = { "prettier" },
      typescriptreact = { "prettier" },
      json = { "prettier" },
    },
    format_on_save = {
      timeout_ms = 1000,
      lsp_format = "never",
    },
  },
}
