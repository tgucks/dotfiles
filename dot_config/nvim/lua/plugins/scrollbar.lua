-- Scrollbar with git and diagnostic markers
return {
  "petertriho/nvim-scrollbar",
  dependencies = { "lewis6991/gitsigns.nvim", "catppuccin/nvim" },
  config = function()
    local colors = require("catppuccin.palettes").get_palette("macchiato")
    require("scrollbar").setup({
      handle = {
        blend = 30,
        color = colors.surface2,
      },
      marks = {
        GitAdd    = { color = colors.green },
        GitChange = { color = colors.yellow },
        GitDelete = { color = colors.red },
      },
      excluded_filetypes = { "NvimTree", "neo-tree", "lazy", "mason" },
    })
    require("scrollbar.handlers.gitsigns").setup()

    -- Only show scrollbar in the active window
    local group = vim.api.nvim_create_augroup("ScrollbarActiveOnly", { clear = true })
    vim.api.nvim_create_autocmd("WinLeave", {
      group = group,
      callback = function()
        local buf = vim.api.nvim_get_current_buf()
        for name, ns_id in pairs(vim.api.nvim_get_namespaces()) do
          if name:match("^Scrollbar") then
            vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
          end
        end
      end,
    })
  end,
}
