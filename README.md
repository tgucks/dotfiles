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
zsh/.zshrc       # shared zsh config (symlinked to ~/.zshrc)
nvim/            # neovim config
tmux/            # tmux config
install.sh       # bootstrap script for new machines
```
