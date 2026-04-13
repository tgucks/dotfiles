return {
  "nvim-tree/nvim-tree.lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local api = require("nvim-tree.api")

    require("nvim-tree").setup({
      filters = { dotfiles = false, git_ignored = false },
      actions = {
        open_file = {
          window_picker = { enable = false },
        },
      },
      on_attach = function(bufnr)
        local function map(key, fn, desc)
          vim.keymap.set("n", key, fn, { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true })
        end

        api.config.mappings.default_on_attach(bufnr)

        local clipboard_path = nil

        map("c", function()
          local node = api.tree.get_node_under_cursor()
          if node and node.absolute_path then
            clipboard_path = node.absolute_path
            vim.notify("Copied: " .. clipboard_path, vim.log.levels.INFO, { title = "nvim-tree" })
          end
        end, "Copy path to clipboard")

        map("p", function()
          if not clipboard_path then
            vim.notify("Nothing copied", vim.log.levels.WARN, { title = "nvim-tree" })
            return
          end
          vim.ui.input({ prompt = "Copy to: ", default = clipboard_path, completion = "file" }, function(dest)
            if not dest or dest == "" then return end
            local dir = vim.fn.fnamemodify(dest, ":h")
            local res = vim.fn.system({ "mkdir", "-p", dir })
            if vim.v.shell_error ~= 0 then
              vim.notify(res, vim.log.levels.ERROR, { title = "nvim-tree" })
              return
            end
            vim.fn.system({ "cp", "-R", clipboard_path, dest })
            api.tree.reload()
          end)
        end, "Paste (copy file to)")

        map("m", function()
          local node = api.tree.get_node_under_cursor()
          if not node or not node.absolute_path then return end
          local src = node.absolute_path
          vim.ui.input({ prompt = "Move to: ", default = src, completion = "file" }, function(dest)
            if not dest or dest == "" then return end
            local dir = vim.fn.fnamemodify(dest, ":h")
            local res = vim.fn.system({ "mkdir", "-p", dir })
            if vim.v.shell_error ~= 0 then
              vim.notify(res, vim.log.levels.ERROR, { title = "nvim-tree" })
              return
            end
            vim.fn.system({ "mv", src, dest })
            api.tree.reload()
          end)
        end, "Move file to")
      end,
    })
    vim.keymap.set("n", "\\", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file tree" })
    vim.keymap.set("n", "|", "<cmd>NvimTreeFindFile<CR>", { desc = "Reveal file in tree" })
  end,
}
