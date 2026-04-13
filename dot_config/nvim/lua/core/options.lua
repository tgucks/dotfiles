-- Disable netrw in favour of nvim-tree
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Leader must be set before plugins load so plugin keymaps pick it up
vim.g.mapleader = ","

-- Basic options
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.termguicolors = true
vim.opt.list = true
vim.opt.listchars = { trail = "·", tab = "  " }
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.clipboard = "unnamedplus"

-- Default indentation: 2 spaces
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
