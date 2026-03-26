# dotfiles

Portable dotfiles for zsh, neovim, and tmux, managed with [chezmoi](https://chezmoi.io).

## Quick start

### New machine
```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply tgucks --source ~/dotfiles
```

### Existing machine
```bash
chezmoi update    # git pull + apply
```

## Daily workflow

```bash
chezmoi edit ~/.zshrc    # edit a managed file (opens source copy)
chezmoi apply            # apply source -> home
chezmoi cd               # cd into the source repo to commit/push

chezmoi re-add ~/.zshrc  # pull back a direct edit into source
chezmoi diff             # preview what apply would change
```

## Machine-specific config

`chezmoi init` prompts for machine type (`personal`/`work`/`server`), git identity, and work-only values (API endpoints, etc.). These are stored in `~/.config/chezmoi/chezmoi.toml` (never committed). Templates use these values to generate the right config per machine.

## Structure

```
dot_zshrc.tmpl              -> ~/.zshrc
dot_zsh_aliases.tmpl        -> ~/.zsh_aliases
dot_tmux.conf               -> ~/.tmux.conf
dot_gitconfig.tmpl          -> ~/.gitconfig
dot_config/nvim/            -> ~/.config/nvim/
dot_config/ghostty/config   -> ~/.config/ghostty/config
dot_config/bat/config       -> ~/.config/bat/config
dot_config/dot_ripgreprc    -> ~/.config/.ripgreprc
dot_claude/                 -> ~/.claude/ (settings merged via modify_ script)
git/gitconfig               -> included via [include] in ~/.gitconfig
```

## Claude settings

`dot_claude/modify_settings.json.tmpl` deep-merges managed settings into `~/.claude/settings.json` at apply time. Keys that Claude writes at runtime (e.g., `model`) are preserved. Machine-specific values (API URLs) come from `chezmoi.toml` data.
