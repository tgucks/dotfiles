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

After install, add any machine-specific config to `~/.zshrc.local` (sourced automatically).

## Structure

```
zsh/.zshrc       # shared zsh config (symlinked to ~/.zshrc)
nvim/            # neovim config
tmux/            # tmux config
install.sh       # bootstrap script for new machines
test/Dockerfile  # Docker setup for testing in a clean environment
```

## Testing with Docker

The Dockerfile in `test/` provides a clean Ubuntu environment to verify dotfiles work on a fresh machine.

```bash
docker build -t dotfiles-test -f test/Dockerfile .
docker run -it --rm -v ~/dotfiles:/home/testuser/dotfiles dotfiles-test
```

Then inside the container:

```bash
cd dotfiles && ./install.sh
```
