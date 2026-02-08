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
    unzip \
    zsh \
    && sudo rm -rf /var/lib/apt/lists/*

  # Set locale (avoids warnings from Homebrew and various tools)
  sudo locale-gen en_US.UTF-8
  export LANG=en_US.UTF-8
fi

# --- Homebrew ---
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add brew to PATH for the rest of this script
  if [[ -d /opt/homebrew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -d /home/linuxbrew/.linuxbrew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
fi

# --- Brew packages ---
echo "Installing packages..."
brew bundle --file=~/dotfiles/Brewfile

# --- Oh My Zsh ---
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# --- Symlinks ---
echo "Creating symlinks..."
ln -sf ~/dotfiles/zsh/.zshrc ~/.zshrc
ln -sf ~/dotfiles/tmux/tmux.conf ~/.tmux.conf

# --- TPM (Tmux Plugin Manager) ---
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  echo "Installing TPM..."
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi
~/.tmux/plugins/tpm/bin/install_plugins

echo "Done! Restart your shell or run: source ~/.zshrc"
