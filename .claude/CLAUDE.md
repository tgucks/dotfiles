## Project Context
This repo is a dotfiles/config management setup. Primary languages: Shell/Zsh, Lua (Neovim), YAML, Go, Markdown. Key tools: Neovim, tmux, Ghostty terminal, Oh-My-Zsh, Homebrew (macOS). Always use Homebrew-installed tool paths over system defaults.

## Debugging

- When diagnosing shell/terminal issues, always check the actual shell version and invocation method first. Scripts may be explicitly invoked with a specific shell (e.g., `bash script.sh`), bypassing shebangs entirely.

## Neovim

- For Neovim configuration changes: always check the exact plugin API and option names before editing. Prefer editorconfig-aware solutions over hard-coded globals for formatting.
- `auto-session` writes one session file per cwd. Tmux-resurrect must NOT inject `:AutoSession restore` / `+SessionRestore` / `--resume` into restored nvim panes - the user often runs multiple nvim instances in one cwd, and a shared restore causes `E303: Unable to open swap file` collisions and disables auto-save. Resurrect should re-run each pane's saved command verbatim. Manual `vim --resume` (one nvim at a time) is fine.

## Third-party plugins & libraries

- Before writing custom code to solve a problem with a third-party plugin or library, check the plugin's documentation and source for a built-in option that does the same thing. Prefer the built-in. Only roll your own if no built-in exists or it is genuinely insufficient, and say why. (Example: `nvim-scrollbar`'s `show_in_active_only = true` is the right base mechanism, but its default event set has gaps — `:vsplit` doesn't fire a leave on the passive pane, and `BufWinLeave` fires after window close with focus already moved, wiping the new active pane. The fix is to *use* the built-in and add a minimal reconciliation layer, not to reinvent it.)
