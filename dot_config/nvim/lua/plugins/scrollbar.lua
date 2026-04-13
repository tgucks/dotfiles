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
  end,
}
