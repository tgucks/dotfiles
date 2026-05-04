return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  config = function()
    local ts = require("nvim-treesitter")
    local parsers = {
      "bash", "c", "css", "dockerfile", "go", "html", "javascript",
      "json", "lua", "make", "markdown", "markdown_inline", "python",
      "regex", "rust", "sql", "toml", "tsx", "typescript", "vim", "vimdoc", "yaml",
    }
    local installed = ts.get_installed()
    local to_install = vim.tbl_filter(function(p)
      return not vim.list_contains(installed, p)
    end, parsers)
    if #to_install > 0 then
      ts.install(to_install)
    end

    vim.api.nvim_create_autocmd("FileType", {
      callback = function(args)
        local lang = vim.treesitter.language.get_lang(args.match) or args.match
        if pcall(vim.treesitter.language.inspect, lang) then
          vim.treesitter.start(args.buf, lang)
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end,
}
