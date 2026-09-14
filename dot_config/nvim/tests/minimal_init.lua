local tests_dir = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))
local config_dir = vim.fs.dirname(tests_dir)

vim.opt.runtimepath:prepend(config_dir)
dofile(config_dir .. "/init.lua")
