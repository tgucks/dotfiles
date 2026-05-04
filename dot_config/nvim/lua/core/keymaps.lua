-- Forward-delete in insert mode (fn+delete on macOS).
-- Use <Del> directly: <Right><BS> misbehaves with softtabstop, deleting a whole
-- indent group instead of one character when whitespace is in front of the cursor.
vim.keymap.set('i', '<C-d>', '<Del>', { desc = "Forward delete" })

-- Exit insert mode without reaching for Esc
vim.keymap.set('i', 'jj', '<Esc>', { desc = "Exit insert mode" })
vim.keymap.set('i', 'kk', '<Esc>', { desc = "Exit insert mode" })
vim.keymap.set('i', 'kj', '<Esc>', { desc = "Exit insert mode" })

-- Comment toggle: current line (normal) or selection (visual)
vim.keymap.set('n', '<leader>/', 'gcc', { remap = true, desc = "Toggle comment" })
vim.keymap.set('v', '<leader>/', 'gc',  { remap = true, desc = "Toggle comment" })

-- Paste in visual mode without clobbering the yank register
vim.keymap.set('x', 'p', '"_dP', { desc = "Paste without overwriting register" })

-- Expand inline collection to multiline (<leader>J, opposite of J which joins)
vim.keymap.set("n", "<leader>J", function()
  local lnum = vim.fn.line(".")
  local line = vim.api.nvim_get_current_line()
  local indent = line:match("^(%s*)")
  local inner = indent .. string.rep(" ", vim.fn.shiftwidth())
  local comma_indent = line:match("[{%[]") and inner or indent
  local result = line
  result = result:gsub("([{%[])%s*", "%1\n" .. inner)
  result = result:gsub(",%s*", ",\n" .. comma_indent)
  result = result:gsub("%s*([%]}])", "\n" .. indent .. "%1")
  vim.api.nvim_buf_set_lines(0, lnum - 1, lnum, false, vim.split(result, "\n"))
end, { desc = "Expand inline to multiline" })

-- Close all floating windows and suppress auto-reopen until cursor moves
vim.keymap.set("n", "<Esc>", function()
  vim.b[vim.api.nvim_get_current_buf()].lsp_float_state = "dismissed"
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative ~= "" then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
end, { desc = "Close floats" })
