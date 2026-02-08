FROM ubuntu:latest

ARG DEBIAN_FRONTEND=noninteractive

# Minimal dependencies for Homebrew and general dotfiles setup
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    file \
    git \
    locales \
    sudo \
    zsh \
    && rm -rf /var/lib/apt/lists/*

# Set locale (avoids warnings from Homebrew and various tools)
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8

# Create a non-root user (Homebrew refuses to run as root)
RUN useradd -m -s /bin/zsh testuser \
    && echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER testuser
WORKDIR /home/testuser

# Install Homebrew
RUN /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add Homebrew to PATH
# ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"

# Your dotfiles get mounted at runtime via -v flag
# Usage:
#   docker build -t dotfiles-test .
#   docker run -it --rm -v ~/dotfiles:/home/testuser/dotfiles dotfiles-test
#
# Then inside the container:
#   cd dotfiles && ./install.sh

CMD ["zsh"]

