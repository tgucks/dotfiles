-- Change/delete/add surrounding pairs: cs"', ds(, ysiw], etc.
return {
  "kylechui/nvim-surround",
  event = "VeryLazy",
  config = function()
    require("nvim-surround").setup()
  end,
}
