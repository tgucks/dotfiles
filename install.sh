#!/bin/bash
set -e

# --- System dependencies (Linux) ---
if [[ "$(uname)" == "Linux" ]]; then
  echo "Installing system dependencies..."
  sudo apt-get update && sudo apt-get install -y \
    build-essential \
    curl \
    file \
    fonts-firacode \
    git \
    locales \
    neovim \
    unzip \
    zsh \
    && sudo rm -rf /var/lib/apt/lists/*

  # Set locale (avoids warnings from Homebrew and various tools)
  sudo locale-gen en_US.UTF-8
  export LANG=en_US.UTF-8
fi

# --- Homebrew + Brewfile (macOS) ---
if [[ "$(uname)" == "Darwin" ]]; then
  if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  echo "Installing from Brewfile..."
  brew bundle --file=~/dotfiles/Brewfile || echo "Warning: some Homebrew packages failed to install, continuing..."
fi

# --- Oh My Zsh ---
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# --- Symlinks ---
echo "Creating symlinks..."
ln -sf ~/dotfiles/zsh/.zshrc ~/.zshrc
ln -sf ~/dotfiles/tmux/tmux.conf ~/.tmux.conf
ln -sf ~/dotfiles/nvim ~/.config/nvim

# --- Neovim plugins ---
if command -v nvim &>/dev/null; then
  echo "Installing Neovim plugins..."
  nvim --headless "+Lazy! sync" +qa 2>&1 || true
  nvim --headless "+TSUpdate" +qa 2>&1 || true
fi

# --- TPM (Tmux Plugin Manager) ---
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  echo "Installing TPM..."
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi
~/.tmux/plugins/tpm/bin/install_plugins

# --- Set default shell to zsh ---
ZSH_PATH="$(which zsh)"
if [[ "$SHELL" != *"zsh"* ]] && [[ -n "$ZSH_PATH" ]]; then
  echo "Changing default shell to zsh..."
  grep -qxF "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
  sudo chsh -s "$ZSH_PATH" "$(whoami)"
fi

echo "Done! Restart your shell or run: exec zsh"
