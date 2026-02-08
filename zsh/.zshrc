#!/bin/bash

# Uncomment when ready
# ln -sf ~/dotfiles/nvim ~/.config/nvim
# ln -sf ~/dotfiles/tmux/tmux.conf ~/.tmux.conf
# ln -sf ~/dotfiles/zsh/.zshrc ~/.zshrc

# Temp testing
ln -s ~/dotfiles/nvim ~/.config/nvim-fresh
export TMUX_PLUGIN_MANAGER_PATH='~/dotfiles/tmux/plugins'

alias vf='NVIM_APPNAME=nvim-fresh nvim'
alias zshf='ZDOTDIR=~/dotfiles/zsh zsh'
alias tmuxf='tmux -f ~/dotfiles/tmux/tmux.conf new-session -s fresh'
