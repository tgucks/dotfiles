# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Portable dotfiles for zsh, neovim, and tmux. The install script bootstraps a new machine by installing dependencies and symlinking configs into place.

## Bootstrap / install

```bash
./install.sh
```

Re-running is safe — all symlinks and the git `[include]` are idempotent.

## Architecture

### Symlink model

`install.sh` symlinks config files into the locations each tool expects:

| Dotfile | Symlinked to |
|---|---|
| `zsh/.zshrc` | `~/.zshrc` |
| `zsh/.zsh_aliases` | `~/.zsh_aliases` |
| `tmux/tmux.conf` | `~/.tmux.conf` |
| `nvim/` | `~/.config/nvim` |
| `ghostty/config` | `~/.config/ghostty/config` |

The nvim directory symlink uses `ln -sfn` (not `-sf`) to avoid creating a recursive symlink on re-runs.

### Git config split

Shared git aliases live in `git/gitconfig` (tracked). The install script appends an `[include]` pointing to it into the local `~/.gitconfig` (untracked), preserving any machine-specific or work identity config already there.

### Neovim plugins

Managed by [lazy.nvim](https://github.com/folke/lazy.nvim), bootstrapped automatically on first launch. `lazy-lock.json` is committed to pin plugin versions. After adding a plugin, run `:Lazy sync` inside nvim to update the lockfile.

### Indentation

Neovim defaults to 2-space indentation. The `editorconfig-vim` plugin overrides this per-repo when a `.editorconfig` is present.
