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
| `claude/statusline-command.sh` | `~/.claude/statusline-command.sh` |
| `claude/fix-plugin-perms.sh` | `~/.claude/hooks/fix-plugin-perms.sh` |
| `claude/skills/scan-secrets/` | `~/.claude/skills/scan-secrets` |
| `bat/config` | `~/.config/bat/config` |

`claude/settings.json` is **not** symlinked — see the Claude settings section below.

The nvim directory symlink uses `ln -sfn` (not `-sf`) to avoid creating a recursive symlink on re-runs.

### Claude settings

`claude/settings.json` holds shared, non-sensitive settings and is tracked in git. Machine-specific settings (API base URLs, internal marketplaces, env vars, etc.) go in `~/.claude/settings.local.json` — this file lives outside the repo and is never committed.

The `claude()` shell function in `zsh/.zsh_aliases` merges all three layers at launch time:

1. `~/dotfiles/claude/settings.json` — shared base
2. `~/.claude/settings.json` — live file (preserves any changes Claude writes automatically)
3. `~/.claude/settings.local.json` — machine-specific overrides (highest precedence)

To add machine-specific settings on a new machine, create `~/.claude/settings.local.json` manually. There is no install step — the function picks it up automatically.

### Git config split

Shared git aliases live in `git/gitconfig` (tracked). The install script appends an `[include]` pointing to it into the local `~/.gitconfig` (untracked), preserving any machine-specific or work identity config already there.

### Neovim plugins

Managed by [lazy.nvim](https://github.com/folke/lazy.nvim), bootstrapped automatically on first launch. `lazy-lock.json` is committed to pin plugin versions. After adding a plugin, run `:Lazy sync` inside nvim to update the lockfile.

### Indentation

Neovim defaults to 2-space indentation. The `editorconfig-vim` plugin overrides this per-repo when a `.editorconfig` is present.
