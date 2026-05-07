return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    require("lualine").setup({
      options = {
        theme = "catppuccin-macchiato",
      },
      sections = {
        lualine_a = {'mode'},
        lualine_b = {
          'branch',
          {
            'diff',
            source = function()
              local gs = vim.b.gitsigns_status_dict
              if gs then
                return { added = gs.added, modified = gs.changed, removed = gs.removed }
              end
            end,
          },
          'diagnostics',
        },
        lualine_c = {{'filename', path = 1}},
        lualine_x = {'encoding', 'fileformat', 'filetype'},
        lualine_y = {'progress'},
        lualine_z = {'location'}
      },
      -- Inactive windows: show the same relative path as active windows
      -- (default only shows the bare filename, which makes it hard to tell
      -- which file lives in which split).
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = {{'filename', path = 1}},
        lualine_x = {'location'},
        lualine_y = {},
        lualine_z = {},
      },
    })
  end,
}
