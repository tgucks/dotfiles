local path = assert(vim.env.NVIM_SQL_TEST_FILE, "NVIM_SQL_TEST_FILE is required")

vim.cmd.edit(vim.fn.fnameescape(path))
vim.wait(5000, function()
  return vim.bo.filetype ~= ""
end)

assert(vim.bo.filetype == "sql", "expected *.psql to use filetype=sql, got " .. vim.bo.filetype)

local buf = vim.api.nvim_get_current_buf()
assert(vim.treesitter.highlighter.active[buf], "expected Tree-sitter highlighting for *.psql")
assert(vim.lsp.is_enabled("postgres_lsp"), "expected postgres_lsp to be enabled")

local attached = vim.wait(10000, function()
  return #vim.lsp.get_clients({ bufnr = buf, name = "postgres_lsp" }) > 0
end)
assert(attached, "expected postgres_lsp to attach to *.psql")

vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "SELEC 1;" })
local diagnosed = vim.wait(10000, function()
  return #vim.diagnostic.get(buf) > 0
end)
assert(diagnosed, "expected postgres_lsp diagnostics for invalid PostgreSQL")
