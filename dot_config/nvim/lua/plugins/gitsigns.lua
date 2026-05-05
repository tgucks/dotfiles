return {
  "lewis6991/gitsigns.nvim",
  config = function()
    local gitsigns = require("gitsigns")
    gitsigns.setup()

    local function is_hunks_qf()
      local qf = vim.fn.getqflist({ size = 0, title = 0 })
      return qf.size > 0 and qf.title and qf.title:lower():find("hunks") ~= nil
    end

    local function entry_path(item)
      if item.bufnr and item.bufnr > 0 then
        return vim.fn.resolve(vim.api.nvim_buf_get_name(item.bufnr))
      end
      return item.filename and vim.fn.resolve(item.filename) or ""
    end

    local function pick_target(forward)
      local items = vim.fn.getqflist()
      if #items == 0 then return nil end

      local here_path = vim.fn.resolve(vim.api.nvim_buf_get_name(0))
      local here_row = vim.api.nvim_win_get_cursor(0)[1]

      if here_path == "" then
        return forward and 1 or #items
      end

      if forward then
        for i, it in ipairs(items) do
          local p = entry_path(it)
          if p == here_path and it.lnum > here_row then return i end
          if p > here_path then return i end
        end
        return 1
      else
        for i = #items, 1, -1 do
          local it = items[i]
          local p = entry_path(it)
          if p == here_path and it.lnum < here_row then return i end
          if p < here_path then return i end
        end
        return #items
      end
    end

    local function jump(forward)
      local idx = pick_target(forward)
      if not idx then
        vim.notify("No hunks in repo", vim.log.levels.INFO)
        return
      end
      pcall(vim.cmd, idx .. "cc")
    end

    local function ensure_hunks_qf(then_do)
      if is_hunks_qf() then
        then_do()
        return
      end
      gitsigns.setqflist("all", { open = false }, function(err)
        if err then
          vim.notify("gitsigns: " .. err, vim.log.levels.WARN)
          return
        end
        vim.schedule(then_do)
      end)
    end

    vim.keymap.set("n", "<leader>gb", "<cmd>Gitsigns blame<CR>", { desc = "Git blame" })
    vim.keymap.set("n", "<leader>gh", "<cmd>Gitsigns setqflist all<CR>", { desc = "Quickfix: all repo hunks" })
    vim.keymap.set("n", "]h", function() ensure_hunks_qf(function() jump(true) end) end, { desc = "Next hunk (cross-file)" })
    vim.keymap.set("n", "[h", function() ensure_hunks_qf(function() jump(false) end) end, { desc = "Prev hunk (cross-file)" })
  end,
}
