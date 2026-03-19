## Project Context
This repo is a dotfiles/config management setup. Primary languages: Shell/Zsh, Lua (Neovim), YAML, Go, Markdown. Key tools: Neovim, tmux, Ghostty terminal, Oh-My-Zsh, Homebrew (macOS). Always use Homebrew-installed tool paths over system defaults.

## Debugging

- When diagnosing shell/terminal issues, always check the actual shell version and invocation method first. Scripts may be explicitly invoked with a specific shell (e.g., `bash script.sh`), bypassing shebangs entirely.

## Neovim

- For Neovim configuration changes: always check the exact plugin API and option names before editing. Prefer editorconfig-aware solutions over hard-coded globals for formatting.
