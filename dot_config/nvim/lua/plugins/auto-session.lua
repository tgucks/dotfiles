return {
  'rmagatti/auto-session',
  lazy = false,
  priority = 100,
  opts = {
    suppressed_dirs = { '~/', '~/Downloads', '/' },
    auto_restore = false,
    auto_restore_last_session = false,
  },
  config = function(_, opts)
    require('auto-session').setup(opts)

    -- auto-session only saves on VimLeavePre, which is skipped when nvim
    -- is killed (tmux server restart, SIGKILL, etc). Save on FocusLost and
    -- after writes so the on-disk session matches what's actually open.
    local function save_session()
      local ok, autosession = pcall(require, 'auto-session')
      if not ok then return end
      pcall(autosession.save_session, nil, { show_message = false, is_autosave = true })
    end

    local group = vim.api.nvim_create_augroup('auto_session_safety_save', { clear = true })
    vim.api.nvim_create_autocmd({ 'FocusLost', 'BufWritePost', 'CursorHold' }, {
      group = group,
      callback = save_session,
    })
  end,
}
