# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Portable dotfiles for zsh, neovim, and tmux, managed with [chezmoi](https://chezmoi.io). The repo is the chezmoi source directory (`~/dotfiles`).

## Bootstrap / apply

```bash
chezmoi apply     # apply all configs
chezmoi update    # git pull + apply
```

## Architecture

### chezmoi model

chezmoi copies real files (not symlinks) from the source directory to the home directory. Files with `.tmpl` suffix are Go templates processed at apply time. Files with `modify_` prefix merge into existing targets instead of replacing them.

Machine-specific values (git identity, API URLs, machine type) are stored in `~/.config/chezmoi/chezmoi.toml` and referenced in templates via `{{ .variableName }}`.

### Source file mapping

| Source | Target |
|---|---|
| `dot_zshrc.tmpl` | `~/.zshrc` |
| `dot_zsh_aliases.tmpl` | `~/.zsh_aliases` |
| `dot_tmux.conf` | `~/.tmux.conf` |
| `dot_gitconfig.tmpl` | `~/.gitconfig` |
| `dot_psqlrc` | `~/.psqlrc` |
| `dot_config/nvim/` | `~/.config/nvim/` |
| `dot_config/ghostty/config` | `~/.config/ghostty/config` |
| `dot_config/bat/config` | `~/.config/bat/config` |
| `dot_config/dot_ripgreprc` | `~/.config/.ripgreprc` |
| `dot_claude/` | `~/.claude/` |

### Terminal

- The repo tracks a ghostty config at `dot_config/ghostty/config`, but the user's actual terminal is iTerm2. Treat the ghostty config as unused/legacy — do not assume terminal-related changes should go there.

### Claude settings

`dot_claude/modify_settings.json.tmpl` is a modify script that deep-merges managed settings into `~/.claude/settings.json`. Keys that Claude writes at runtime (e.g., `model`) are preserved. Machine-specific values (API URLs) come from `chezmoi.toml` data, never committed.

### Git config

`dot_gitconfig.tmpl` generates `~/.gitconfig` with identity from chezmoi data, `[includeIf]` directives for work machines, and an `[include]` pointing to `git/gitconfig` for shared aliases.

### Scripts

| Script | Runs when |
|---|---|
| `run_once_before_01-install-packages.sh.tmpl` | Once (Homebrew/apt packages) |
| `run_once_before_02-install-oh-my-zsh.sh` | Once (Oh My Zsh) |
| `run_once_before_03-set-default-shell.sh` | Once (chsh to zsh) |
| `run_onchange_after_nvim-plugins.sh.tmpl` | When any nvim `*.lua` file changes |
| `run_onchange_after_tpm-plugins.sh.tmpl` | When `tmux.conf` changes |

### Neovim plugins

Managed by [lazy.nvim](https://github.com/folke/lazy.nvim), bootstrapped automatically on first launch. Config is modular: `lua/core/` holds options, keymaps, and autocmds; `lua/plugins/` has one file per plugin (lazy.nvim auto-discovers them via `import`). `lazy-lock.json` is committed to pin plugin versions. After adding a plugin, create a new file in `lua/plugins/` and run `:Lazy sync` inside nvim to update the lockfile.

### Indentation

Neovim defaults to 2-space indentation. The `editorconfig-vim` plugin overrides this per-repo when a `.editorconfig` is present.
