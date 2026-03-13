# dotfiles

Portable dotfiles for zsh, neovim, and tmux.

## Quick start

```bash
git clone https://github.com/tgucks/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

`install.sh` will:
- Install [Homebrew](https://brew.sh) if not already present
- Install packages (Pure prompt)
- Symlink config files to your home directory

## Structure

```
zsh/.zshrc                # shared zsh config (symlinked to ~/.zshrc)
nvim/                     # neovim config
tmux/                     # tmux config
claude/settings.json      # shared Claude Code settings (not symlinked — see below)
install.sh                # bootstrap script for new machines
```

## Machine-specific Claude settings

`claude/settings.json` contains shared Claude Code settings tracked in git. To add settings that should only apply to one machine (API endpoints, internal tool marketplaces, env vars), create `~/.claude/settings.local.json` — it is not part of this repo.

The `claude()` function in `zsh/.zsh_aliases` automatically merges `claude/settings.json`, the live `~/.claude/settings.json`, and `~/.claude/settings.local.json` on every invocation, with the local file taking highest precedence.
