return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,
  config = function()
    require("catppuccin").setup({
      transparent_background = true,
      auto_integrations = true,
      -- Give the statusline an opaque bg so horizontal splits have a visible
      -- divider bar. catppuccin's lualine integration forces bg=NONE when
      -- transparent_background is on, which hides the whole statusline.
      integrations = {
        lualine = {
          all = function(C)
            return {
              normal = { c = { bg = C.mantle, fg = C.text } },
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
          -- Paint the non-lualine edges of the statusline so the whole
          -- row reads as one continuous horizontal bar.
          StatusLine = { bg = colors.mantle, fg = colors.text },
          StatusLineNC = { bg = colors.mantle, fg = colors.overlay1 },
        }
      end,
    })
  end,
}
