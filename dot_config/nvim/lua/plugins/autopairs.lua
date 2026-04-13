-- Auto-close pairs: (), [], {}, "", '', ``, etc.
return {
  "windwp/nvim-autopairs",
  event = "InsertEnter",
  config = function()
    require("nvim-autopairs").setup()
  end,
}
