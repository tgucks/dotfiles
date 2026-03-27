#!/bin/bash
set -euo pipefail

ZSH_PATH="$(which zsh 2>/dev/null || true)"
if [[ -n "$ZSH_PATH" && "$SHELL" != *"zsh"* ]]; then
    echo "Changing default shell to zsh..."
    grep -qxF "$ZSH_PATH" /etc/shells 2>/dev/null || echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
    sudo chsh -s "$ZSH_PATH" "$(whoami)" || true
fi
