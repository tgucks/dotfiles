-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Core settings (must load before plugins so mapleader is set)
require("core.options")
require("core.keymaps")
require("core.autocmds")

-- Plugins (auto-discovers all files in lua/plugins/)
require("lazy").setup({ import = "plugins" })

-- Post-plugin: colorscheme and highlight overrides
vim.cmd.colorscheme "catppuccin-macchiato"
vim.api.nvim_set_hl(0, "Whitespace", { fg = "#494d64" })
