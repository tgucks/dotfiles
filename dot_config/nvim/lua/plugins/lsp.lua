return {
  -- Mason installs language servers automatically
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
        window = {
          winblend = 0,
          avoid = { "NvimTree" },
        },
      },
    },
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig", "hrsh7th/cmp-nvim-lsp", "j-hui/fidget.nvim" },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = { "gopls", "basedpyright", "ruff", "ts_ls", "eslint", "bashls" },
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

      -- Format Python files on save (ruff LSP handles formatting)
      vim.api.nvim_create_autocmd("BufWritePre", {
        pattern = "*.py",
        callback = function()
          -- Pin to ruff so basedpyright (no formatter) doesn't receive the request
          vim.lsp.buf.format({ async = false, name = "ruff" })
        end,
      })

      -- Auto-fix ESLint violations on save for JS/TS/React files.
      -- LspEslintFixAll is a buffer-local command registered by the eslint LSP
      -- on attach, so it only exists once the client is attached to this
      -- buffer. Three states to distinguish:
      --   1. Attached here           -> run the fix
      --   2. Running, not yet here   -> warn (avoids silent skip on races)
      --   3. Not running anywhere    -> silent skip (project has no eslint)
      vim.api.nvim_create_autocmd("BufWritePre", {
        pattern = { "*.js", "*.jsx", "*.ts", "*.tsx", "*.mjs", "*.cjs" },
        callback = function(args)
          if #vim.lsp.get_clients({ bufnr = args.buf, name = "eslint" }) > 0 then
            vim.cmd("LspEslintFixAll")
          elseif #vim.lsp.get_clients({ name = "eslint" }) > 0 then
            vim.notify("eslint LSP not attached to this buffer yet; skipping fix", vim.log.levels.WARN)
          end
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

      -- Python: type checking, hover, completions, go-to-definition
      vim.lsp.config("basedpyright", {
        capabilities = capabilities,
        settings = {
          basedpyright = {
            analysis = {
              typeCheckingMode = "standard",
              autoImportCompletions = true,
            },
          },
        },
      })
      vim.lsp.enable("basedpyright")

      -- Python: linting diagnostics + formatting
      vim.lsp.config("ruff", {
        capabilities = capabilities,
        init_options = {
          settings = {
            lineLength = 88,
          },
        },
        on_attach = function(client)
          -- Disable ruff hover - basedpyright's type-aware hover is richer
          client.server_capabilities.hoverProvider = false
        end,
      })
      vim.lsp.enable("ruff")

      -- JS/TS/React: completions, type checking, hover, go-to-definition
      vim.lsp.config("ts_ls", {
        capabilities = capabilities,
        settings = {
          typescript = {
            inlayHints = {
              includeInlayParameterNameHints = "all",
              includeInlayFunctionParameterTypeHints = true,
              includeInlayVariableTypeHints = true,
              includeInlayPropertyDeclarationTypeHints = true,
              includeInlayFunctionLikeReturnTypeHints = true,
            },
          },
          javascript = {
            inlayHints = {
              includeInlayParameterNameHints = "all",
              includeInlayFunctionParameterTypeHints = true,
              includeInlayVariableTypeHints = true,
              includeInlayPropertyDeclarationTypeHints = true,
              includeInlayFunctionLikeReturnTypeHints = true,
            },
          },
        },
      })
      vim.lsp.enable("ts_ls")

      -- JS/TS/React: linting and auto-fix via ESLint LSP
      vim.lsp.config("eslint", {
        capabilities = capabilities,
      })
      vim.lsp.enable("eslint")

      -- Rounded borders on diagnostic float
      vim.diagnostic.config({
        float = { border = "rounded", source = true },
      })
    end,
  },
}
