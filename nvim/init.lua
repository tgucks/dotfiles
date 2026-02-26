-- Disable netrw in favour of nvim-tree
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

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
vim.opt.relativenumber = true
vim.opt.termguicolors = true
vim.opt.list = true
vim.opt.listchars = { trail = "·", tab = "  " }
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.clipboard = "unnamedplus"

-- Undercurl
-- vim.cmd([[let &t_Cs = "\e[4:3m"]])
-- vim.cmd([[let &t_Ce = "\e[4:0m"]])

-- Active window: hybrid line numbers (current = absolute, others = relative)
-- Inactive windows: absolute only
vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
  callback = function() vim.opt_local.relativenumber = true end,
})
vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
  callback = function() vim.opt_local.relativenumber = false end,
})

-- Leader must be set before plugins load so plugin keymaps pick it up
vim.g.mapleader = ","

-- Default indentation: 2 spaces
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2

-- Forward-delete in insert mode (fn+delete on macOS)
vim.keymap.set('i', '<C-d>', '<Right><BS>', { desc = "Forward delete" })

-- Exit insert mode without reaching for Esc
vim.keymap.set('i', 'jj', '<Esc>', { desc = "Exit insert mode" })
vim.keymap.set('i', 'kk', '<Esc>', { desc = "Exit insert mode" })
vim.keymap.set('i', 'kj', '<Esc>', { desc = "Exit insert mode" })

-- Comment toggle: current line (normal) or selection (visual)
vim.keymap.set('n', '<leader>/', 'gcc', { remap = true, desc = "Toggle comment" })
vim.keymap.set('v', '<leader>/', 'gc',  { remap = true, desc = "Toggle comment" })

-- Paste in visual mode without clobbering the yank register
vim.keymap.set('x', 'p', '"_dP', { desc = "Paste without overwriting register" })

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
  -- File tree
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        filters = { dotfiles = false },
        actions = {
          open_file = {
            window_picker = { enable = false },
          },
        },
      })
      vim.keymap.set("n", "\\", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file tree" })
      vim.keymap.set("n", "|", "<cmd>NvimTreeFindFile<CR>", { desc = "Reveal file in tree" })
    end,
  },
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
  -- Theme
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        transparent_background = true,
        auto_integrations = true,
      })
    end
  },
  -- {
  --   "Mofiqul/dracula.nvim",
  --   priority = 1000,
  --   config = function()
  --     vim.cmd("colorscheme dracula")
  --   end,
  -- },
  -- {
  --   "craftzdog/solarized-osaka.nvim",
  --   lazy = false,
  --   priority = 1000,
  --   opts = {},
  --   config = function()
  --     vim.cmd("colorscheme solarized-osaka")
  --   end,
  -- },
  -- LSP: Mason installs language servers automatically
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup()
    end,
  },
  -- LSP progress indicator (spinner in the corner while gopls loads)
  {
    "j-hui/fidget.nvim",
    opts = {
      notification = {
        window = { winblend = 0 },
      },
    },
  },
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
          -- gofmt rewrites indentation as tabs; re-apply editorconfig so the
          -- tab display width stays at whatever the project specifies, not the
          -- global default of 2.
          vim.cmd("EditorConfigReload")
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
      vim.lsp.enable("bashls")

      -- Rounded borders on diagnostic float
      vim.diagnostic.config({
        float = { border = "rounded", source = true },
        -- underline = true,
      })

      -- Float popup colours: lighter content bg, dark bg behind the border chars
      -- so the border sits flush at the edge of the lighter area
      vim.api.nvim_set_hl(0, "NormalFloat", { bg = "#44475a" })
      vim.api.nvim_set_hl(0, "FloatBorder", { fg = "#bd93f9", bg = "#282a36" })
      -- vim.api.nvim_set_hl(0, "DiagnosticUnderlineError", { undercurl = true, sp = "#f38ba8" })
      -- vim.api.nvim_set_hl(0, "DiagnosticUnderlineWarn", { undercurl = true, sp = "#f9e2af" })
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
  -- Git signs in the gutter (added/changed/removed lines)
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup()
      vim.keymap.set("n", "<leader>gb", "<cmd>Gitsigns blame<CR>", { desc = "Git blame" })
      vim.keymap.set("n", "]c", "<cmd>Gitsigns next_hunk<CR>", { desc = "Next git hunk" })
      vim.keymap.set("n", "[c", "<cmd>Gitsigns prev_hunk<CR>", { desc = "Prev git hunk" })
    end,
  },
  -- Fuzzy finder
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    config = function()
      require("telescope").setup({
        defaults = {
          vimgrep_arguments = {
            "rg", "--color=never", "--no-heading", "--with-filename",
            "--line-number", "--column", "--smart-case", "--hidden",
            "--glob", "!.git",
          },
          file_ignore_patterns = { "^%.git/" },
          mappings = {
            i = { ["<Esc>"] = require("telescope.actions").close },
          },
        },
        pickers = {
          find_files = { hidden = true },
        },
        extensions = {
          fzf = {},
        },
      })
      require("telescope").load_extension("fzf")
      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<leader>f",  builtin.find_files,  { desc = "Find files" })
      vim.keymap.set("n", "<leader>r", builtin.live_grep,   { desc = "Live grep" })
      vim.keymap.set("v", "<leader>r", function()
        vim.cmd('noau normal! "vy"')
        local text = vim.fn.getreg("v")
        builtin.live_grep({ default_text = text })
      end, { desc = "Live grep visual selection" })
    end,
  },
  -- Scrollbar with git and diagnostic markers
  {
    "petertriho/nvim-scrollbar",
    dependencies = { "lewis6991/gitsigns.nvim" },
    config = function()
      require("scrollbar").setup()
      require("scrollbar.handlers.gitsigns").setup()
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

vim.cmd.colorscheme "catppuccin-macchiato"

-- Subtle colour for trailing-whitespace dots (below the catppuccin surface colours)
vim.api.nvim_set_hl(0, "Whitespace", { fg = "#494d64" })

-- Trim trailing whitespace and empty lines at end of file on explicit :w.
-- Skipped if .editorconfig sets trim_trailing_whitespace = false.
-- Uses BufWritePre so it runs on :w but not on the noautocmd auto-saves.
vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function()
    local ec = vim.b.editorconfig or {}
    if ec.trim_trailing_whitespace == "false" then return end
    local cursor = vim.api.nvim_win_get_cursor(0)
    -- Trim trailing whitespace on every line
    vim.cmd([[keeppatterns %s/\s\+$//e]])
    -- Trim trailing blank lines at end of file
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local last = #lines
    while last > 1 and lines[last]:match("^%s*$") do last = last - 1 end
    if last < #lines then vim.api.nvim_buf_set_lines(0, last, -1, false, {}) end
    pcall(vim.api.nvim_win_set_cursor, 0, cursor)
  end,
})

-- Auto-save: silently write whenever the buffer is modified.
-- Uses `noautocmd` so BufWritePre/BufWritePost hooks (e.g. Go formatter) do NOT fire.
-- The formatter still runs on explicit :w as normal.
local autosave_group = vim.api.nvim_create_augroup("AutoSave", { clear = true })
local function buf_is_saveable()
  return vim.bo.modified and vim.bo.buftype == "" and vim.fn.expand("%") ~= ""
end
-- On change: save silently without triggering BufWritePre hooks (e.g. formatter)
vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
  group = autosave_group,
  callback = function()
    if buf_is_saveable() then vim.cmd("silent! noautocmd write") end
  end,
})
-- On exit/focus loss: save normally so BufWritePre hooks (e.g. formatter) fire
vim.api.nvim_create_autocmd({ "FocusLost", "BufLeave" }, {
  group = autosave_group,
  callback = function()
    if buf_is_saveable() then vim.cmd("silent! write") end
  end,
})
