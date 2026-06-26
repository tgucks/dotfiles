return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,
  config = function()
    require("catppuccin").setup({
      transparent_background = true,
      auto_integrations = true,
      integrations = {
        lualine = {
          all = function(C)
            return {
              inactive = {
                a = { bg = C.mantle, fg = C.blue },
                b = { bg = C.mantle, fg = C.surface1, gui = "bold" },
                c = { bg = C.mantle, fg = C.overlay1 },
              },
            }
          end,
        },
      },
      custom_highlights = function(colors)
        return {
          StatusLineNC = { bg = colors.mantle, fg = colors.overlay1 },
          LineNr = { fg = colors.overlay0 },
        }
      end,
    })
  end,
}
