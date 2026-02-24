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

-- Basic options
vim.opt.number = true
vim.opt.termguicolors = true

-- Leader must be set before plugins load so plugin keymaps pick it up
vim.g.mapleader = ","

-- Default indentation: 2 spaces
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2

-- Reload config
vim.keymap.set("n", "<leader>r", function()
  dofile(vim.fn.stdpath("config") .. "/init.lua")
  vim.notify("Config reloaded")
end, { desc = "Reload config" })

-- Close all floating windows and suppress auto-reopen until cursor moves
vim.keymap.set("n", "<Esc>", function()
  vim.b[vim.api.nvim_get_current_buf()].lsp_float_state = "dismissed"
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative ~= "" then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
end, { desc = "Close floats" })

-- Plugins
require("lazy").setup({
  -- Respect per-repo .editorconfig settings (overrides defaults above)
  { "editorconfig/editorconfig-vim" },
  -- Auto-close pairs: (), [], {}, "", '', ``, etc.
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      require("nvim-autopairs").setup()
    end,
  },
  -- Change/delete/add surrounding pairs: cs"', ds(, ysiw], etc.
  {
    "kylechui/nvim-surround",
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup()
    end,
  },
  {
    "Mofiqul/dracula.nvim",
    priority = 1000,
    config = function()
      vim.cmd("colorscheme dracula")
    end,
  },
  -- LSP: Mason installs language servers automatically
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup()
    end,
  },
  -- LSP progress indicator (spinner in the corner while gopls loads)
  { "j-hui/fidget.nvim", opts = {} },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig", "hrsh7th/cmp-nvim-lsp", "j-hui/fidget.nvim" },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = { "gopls" },
        automatic_installation = true,
      })

      -- Float state is stored in vim.b so the global <Esc> keymap can reach it.
      -- States: nil (fresh) | "hover" | "diagnostic" | "dismissed"
      -- CursorHold only auto-shows when state is nil (i.e. cursor just moved here).
      -- CursorMoved resets state to nil so the next hold auto-shows again.

      local function close_floats()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_win_get_config(win).relative ~= "" then
            pcall(vim.api.nvim_win_close, win, true)
          end
        end
      end

      local function show_diagnostic(buf)
        vim.b[buf].lsp_float_state = "diagnostic"
        vim.diagnostic.open_float({ border = "rounded", source = true, scope = "cursor", focusable = false })
      end

      local function show_hover(buf)
        vim.b[buf].lsp_float_state = "hover"
        vim.lsp.buf.hover({ border = "rounded", max_width = 80, focusable = false })
      end

      -- Keymaps + auto-hover, scoped to buffers with an active LSP
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true }),
        callback = function(args)
          local buf = args.buf
          local function map(keys, func, desc)
            vim.keymap.set("n", keys, func, { buffer = buf, desc = desc })
          end

          map("gd",         vim.lsp.buf.definition,     "Go to definition")
          map("gD",         vim.lsp.buf.declaration,    "Go to declaration")
          map("gr",         vim.lsp.buf.references,     "References")
          map("gi",         vim.lsp.buf.implementation, "Go to implementation")
          map("<leader>rn", vim.lsp.buf.rename,         "Rename symbol")
          map("<leader>ca", vim.lsp.buf.code_action,    "Code action")
          map("[d",         vim.diagnostic.goto_prev,   "Prev diagnostic")
          map("]d",         vim.diagnostic.goto_next,   "Next diagnostic")

          -- K cycles: hover -> diagnostic -> hover
          map("K", function()
            local diags = vim.diagnostic.get(buf, { lnum = vim.fn.line(".") - 1 })
            close_floats()
            if vim.b[buf].lsp_float_state ~= "hover" then
              show_hover(buf)
            elseif #diags > 0 then
              show_diagnostic(buf)
            else
              show_hover(buf)
            end
          end, "Cycle hover/diagnostic")

          -- Reset state when cursor moves so the next CursorHold auto-shows
          vim.api.nvim_create_autocmd("CursorMoved", {
            buffer = buf,
            callback = function() vim.b[buf].lsp_float_state = nil end,
          })

          -- Auto-show on hold, but only when state is nil (cursor just arrived here)
          vim.api.nvim_create_autocmd("CursorHold", {
            buffer = buf,
            callback = function()
              if vim.b[buf].lsp_float_state ~= nil then return end
              local diags = vim.diagnostic.get(buf, { lnum = vim.fn.line(".") - 1 })
              if #diags > 0 then
                show_diagnostic(buf)
              else
                show_hover(buf)
              end
            end,
          })
        end,
      })

      -- Format Go files on save
      vim.api.nvim_create_autocmd("BufWritePre", {
        pattern = "*.go",
        callback = function()
          vim.lsp.buf.format({ async = false })
        end,
      })

      -- updatetime controls how long the cursor must be still before CursorHold fires
      vim.opt.updatetime = 1000

      -- Configure gopls using the new nvim 0.11 API
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      vim.lsp.config("gopls", {
        capabilities = capabilities,
        settings = {
          gopls = {
            analyses = { unusedparams = true, shadow = true },
            staticcheck = true,
          },
        },
      })
      vim.lsp.enable("gopls")

      -- Rounded borders on diagnostic float
      vim.diagnostic.config({
        float = { border = "rounded", source = true },
      })

      -- Float popup colours: lighter content bg, dark bg behind the border chars
      -- so the border sits flush at the edge of the lighter area
      vim.api.nvim_set_hl(0, "NormalFloat", { bg = "#44475a" })
      vim.api.nvim_set_hl(0, "FloatBorder", { fg = "#bd93f9", bg = "#282a36" })
    end,
  },

  -- Autocompletion
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      cmp.setup({
        snippet = {
          expand = function(args) luasnip.lsp_expand(args.body) end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"]      = cmp.mapping.confirm({ select = true }),
          ["<Tab>"]     = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then luasnip.expand_or_jump()
            else fallback() end
          end, { "i", "s" }),
          ["<S-Tab>"]   = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then luasnip.jump(-1)
            else fallback() end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "buffer" },
          { name = "path" },
        }),
      })
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      local ok, configs = pcall(require, "nvim-treesitter.configs")
      if not ok then return end
      configs.setup({
        ensure_installed = {
          "bash",
          "c",
          "css",
          "dockerfile",
          "go",
          "html",
          "javascript",
          "json",
          "lua",
          "make",
          "markdown",
          "markdown_inline",
          "python",
          "regex",
          "rust",
          "toml",
          "tsx",
          "typescript",
          "vim",
          "vimdoc",
          "yaml",
        },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },
})
