## Project Context
This repo is a dotfiles/config management setup. Primary languages: Shell/Zsh, Lua (Neovim), YAML, Go, Markdown. Key tools: Neovim, tmux, Ghostty terminal, Oh-My-Zsh, Homebrew (macOS). Always use Homebrew-installed tool paths over system defaults.

## Debugging

- When diagnosing shell/terminal issues, always check the actual shell version and invocation method first. Scripts may be explicitly invoked with a specific shell (e.g., `bash script.sh`), bypassing shebangs entirely.
- Any end-to-end test that boots a real tmux server on an isolated socket (`tmux -L <socket>`) MUST clean up after itself: `tmux -L <socket> kill-server` and `rm` the socket file plus any scratch `@resurrect-dir`/temp files, ideally via an `EXIT` trap. Stray isolated servers linger and trip tmux-continuum's `another_tmux_server_running_on_startup` guard, which silently suppresses `--resume` restore on unrelated sockets and produces false test failures. Before trusting a resurrect/continuum failure, list live servers (`ps -u $(id -u) | grep '[t]mux'`) and dead-vs-live sockets in `/private/tmp/tmux-$(id -u)/` and kill any leftovers first.

## Neovim

- For Neovim configuration changes: always check the exact plugin API and option names before editing. Prefer editorconfig-aware solutions over hard-coded globals for formatting.
- `auto-session` keys session files by cwd. nvim layout IS restored across tmux-resurrect reboots, but via PER-PANE session files (`tmux__<session>__<window>__<pane>.vim`), never a cwd-shared file. A cwd-shared restore across multiple nvim panes in one dir causes `E303: Unable to open swap file` collisions - that is the trap to avoid, not layout restoration itself. nvim is excluded from `@resurrect-default-processes`; `restore-nvim-sessions.sh` relaunches each pane as `nvim -S <per-pane file>`. Per-pane identity lives in `dot_config/nvim/lua/core/tmux_session.lua`. Manual `vim --resume` (cwd-keyed, one nvim at a time) is unaffected. See memory `auto-session-and-tmux-resurrect-contract`.

## Third-party plugins & libraries

- Before writing custom code to solve a problem with a third-party plugin or library, check the plugin's documentation and source for a built-in option that does the same thing. Prefer the built-in. Only roll your own if no built-in exists or it is genuinely insufficient, and say why. (Example: `nvim-scrollbar`'s `show_in_active_only = true` is the right base mechanism, but its default event set has gaps — `:vsplit` doesn't fire a leave on the passive pane, and `BufWinLeave` fires after window close with focus already moved, wiping the new active pane. The fix is to *use* the built-in and add a minimal reconciliation layer, not to reinvent it.)
