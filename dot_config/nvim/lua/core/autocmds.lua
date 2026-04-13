-- Active window: hybrid line numbers (current = absolute, others = relative)
-- Inactive windows: absolute only
vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
  callback = function() vim.opt_local.relativenumber = true end,
})
vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
  callback = function() vim.opt_local.relativenumber = false end,
})

-- Go filetypes that nvim doesn't detect natively (gopls needs these)
vim.filetype.add({
  filename = { ["go.work"] = "gowork" },
  extension = { gotmpl = "gotmpl" },
  pattern = { [".*%.go%.tmpl"] = "gotmpl" },
})

-- Python convention is 4 spaces (matches ruff's formatter default)
vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
    vim.opt_local.softtabstop = 4
  end,
})

-- Restore terminal cursor (blinking bar, DECSCUSR 5) when leaving nvim.
-- Neovim resets the cursor on exit before the shell's precmd hook fires,
-- so we send the escape sequence explicitly to prevent a stale cursor shape.
vim.api.nvim_create_autocmd("VimLeave", {
  callback = function() io.write("\027[1 q") end,
})

-- Sync lazy-lock.json back to chezmoi source so `chezmoi apply` never conflicts
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "lazy-lock.json",
  callback = function()
    local target = vim.fn.expand("~/.config/nvim/lazy-lock.json")
    vim.fn.jobstart({ "chezmoi", "re-add", target }, { detach = true })
  end,
})

-- Trim trailing whitespace and empty lines at end of file on explicit :w.
-- Skipped if .editorconfig sets trim_trailing_whitespace = false.
-- Uses BufWritePre so it runs on :w but not on the noautocmd auto-saves.
vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function()
    local ec = vim.b.editorconfig or {}
    if ec.trim_trailing_whitespace == "false" then return end
    local cursor = vim.api.nvim_win_get_cursor(0)
    -- Trim trailing whitespace on every line
    vim.cmd([[keeppatterns %s/\s\+$//e]])
    -- Trim trailing blank lines at end of file
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local last = #lines
    while last > 1 and lines[last]:match("^%s*$") do last = last - 1 end
    if last < #lines then vim.api.nvim_buf_set_lines(0, last, -1, false, {}) end
    pcall(vim.api.nvim_win_set_cursor, 0, cursor)
  end,
})

-- Auto-save: silently write whenever the buffer is modified.
-- Uses `noautocmd` so BufWritePre/BufWritePost hooks (e.g. Go formatter) do NOT fire.
-- The formatter still runs on explicit :w as normal.
local autosave_group = vim.api.nvim_create_augroup("AutoSave", { clear = true })
local function buf_is_saveable()
  return vim.bo.modified and vim.bo.buftype == "" and vim.fn.expand("%") ~= ""
end
-- On change: save silently without triggering BufWritePre hooks (e.g. formatter)
vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
  group = autosave_group,
  callback = function()
    if buf_is_saveable() then vim.cmd("silent! noautocmd write") end
  end,
})
-- On exit/focus loss: save normally so BufWritePre hooks (e.g. formatter) fire
vim.api.nvim_create_autocmd({ "FocusLost", "BufLeave" }, {
  group = autosave_group,
  callback = function()
    if buf_is_saveable() then vim.cmd("silent! write") end
  end,
})
