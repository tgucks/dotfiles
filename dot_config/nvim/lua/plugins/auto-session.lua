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
    --
    -- Inside tmux we save to a PER-PANE session keyed on the pane's stable
    -- tmux coordinate, not the cwd. This lets multiple nvim panes share one
    -- cwd without clobbering each other's layout, and lets the tmux-resurrect
    -- restore hook bring each pane back with `nvim -S <its own file>`. Outside
    -- tmux we keep the default cwd-keyed save (the manual --resume wrapper
    -- path is unchanged).
    local tmux_session = require('core.tmux_session')

    local function save_session()
      local ok, autosession = pcall(require, 'auto-session')
      if not ok then return end
      local name = tmux_session.session_name() -- nil when not in tmux
      pcall(autosession.save_session, name, { show_message = false, is_autosave = true })
    end

    local group = vim.api.nvim_create_augroup('auto_session_safety_save', { clear = true })
    vim.api.nvim_create_autocmd({ 'FocusLost', 'BufWritePost', 'CursorHold', 'VimLeavePre' }, {
      group = group,
      callback = save_session,
    })
  end,
}
