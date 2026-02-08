#!/bin/bash
set -e

# --- System dependencies (Linux) ---
if [[ "$(uname)" == "Linux" ]]; then
  echo "Installing system dependencies..."
  sudo apt-get update && sudo apt-get install -y \
    build-essential \
    curl \
    file \
    git \
    locales \
    zsh \
    && sudo rm -rf /var/lib/apt/lists/*

  # Set locale (avoids warnings from Homebrew and various tools)
  sudo locale-gen en_US.UTF-8
  export LANG=en_US.UTF-8
fi

# --- Homebrew ---
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add brew to PATH for the rest of this script
  if [[ -d /opt/homebrew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -d /home/linuxbrew/.linuxbrew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
fi

# --- Brew packages ---
echo "Installing packages..."
brew install pure

# --- Symlinks ---
echo "Creating symlinks..."
ln -sf ~/dotfiles/zsh/.zshrc ~/.zshrc

echo "Done! Restart your shell or run: source ~/.zshrc"
