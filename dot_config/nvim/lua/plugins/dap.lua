-- DAP (Debug Adapter Protocol) - Go debugging with Delve
return {
  "mfussenegger/nvim-dap",
  dependencies = {
    "rcarriga/nvim-dap-ui",
    "nvim-neotest/nvim-nio",
    "leoluz/nvim-dap-go",
  },
  keys = {
    { "<leader>db", function() require("dap").toggle_breakpoint() end,                                    desc = "Toggle breakpoint" },
    { "<leader>dB", function() require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: ")) end, desc = "Conditional breakpoint" },
    { "<leader>dc", function() require("dap").continue() end,                                             desc = "Continue / Start" },
    { "<leader>dn", function() require("dap").step_over() end,                                            desc = "Step over" },
    { "<leader>ds", function() require("dap").step_into() end,                                            desc = "Step into" },
    { "<leader>do", function() require("dap").step_out() end,                                             desc = "Step out" },
    { "<leader>dr", function() require("dap").restart() end,                                              desc = "Restart" },
    { "<leader>dq", function() require("dap").terminate() end,                                            desc = "Terminate" },
    { "<leader>dt", function() require("dap-go").debug_test() end,                                        desc = "Debug nearest test" },
    { "<leader>du", function() require("dapui").toggle() end,                                             desc = "Toggle DAP UI" },
    { "<leader>de", function() require("dapui").inspect() end,                                            desc = "Inspect expression", mode = { "n", "v" } },
    { "<leader>dl", function() require("dap").repl.open() end,                                            desc = "Open REPL" },
  },
  config = function()
    local dap, dapui = require("dap"), require("dapui")
    require("dap-go").setup()
    dapui.setup()

    -- Auto open/close the UI with debug sessions
    dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
    dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
    dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end

    -- Breakpoint appearance
    vim.fn.sign_define("DapBreakpoint",          { text = "●", texthl = "DiagnosticError" })
    vim.fn.sign_define("DapBreakpointCondition",  { text = "◆", texthl = "DiagnosticWarn" })
    vim.fn.sign_define("DapStopped",              { text = "▶", texthl = "DiagnosticOk", linehl = "Visual" })
  end,
}
