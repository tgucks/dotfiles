# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Portable dotfiles for zsh, neovim, and tmux, managed with [chezmoi](https://chezmoi.io). The repo is the chezmoi source directory (`~/dotfiles`).

## Bootstrap / apply

```bash
chezmoi apply     # apply all configs
chezmoi update    # git pull + apply
```

## Architecture

### chezmoi model

chezmoi copies real files (not symlinks) from the source directory to the home directory. Files with `.tmpl` suffix are Go templates processed at apply time. Files with `modify_` prefix merge into existing targets instead of replacing them.

Machine-specific values (git identity, API URLs, machine type) are stored in `~/.config/chezmoi/chezmoi.toml` and referenced in templates via `{{ .variableName }}`.

### Source file mapping

| Source | Target |
|---|---|
| `dot_zshrc.tmpl` | `~/.zshrc` |
| `dot_zsh_aliases.tmpl` | `~/.zsh_aliases` |
| `dot_tmux.conf` | `~/.tmux.conf` |
| `dot_gitconfig.tmpl` | `~/.gitconfig` |
| `dot_psqlrc` | `~/.psqlrc` |
| `dot_config/nvim/` | `~/.config/nvim/` |
| `dot_config/ghostty/config` | `~/.config/ghostty/config` |
| `dot_config/bat/config` | `~/.config/bat/config` |
| `dot_config/dot_ripgreprc` | `~/.config/.ripgreprc` |
| `dot_claude/` | `~/.claude/` |
| `obsidian/` | every opted-in Obsidian vault (via `run_onchange_after_05`) |
| `dot_gitconfig-work.tmpl` | `~/.gitconfig-work` (work machines only) |
| `dot_gitconfig-personal.tmpl` | `~/.gitconfig-personal` (work machines only) |

### Terminal

- The repo tracks a ghostty config at `dot_config/ghostty/config`, but the user's actual terminal is iTerm2. Treat the ghostty config as unused/legacy — do not assume terminal-related changes should go there.

### Claude settings

`dot_claude/modify_settings.json.tmpl` is a modify script that deep-merges managed settings into `~/.claude/settings.json`. Keys that Claude writes at runtime (e.g., `model`) are preserved. Machine-specific values (API URLs) come from `chezmoi.toml` data, never committed.

### Obsidian

`obsidian/` holds vault *config only* - never notes. `apply-obsidian-config.sh` reads Obsidian's own vault registry and copies the config into each vault holding a `.obsidian-managed` marker file - opt-in, so a work vault is never reconfigured by accident; the repo is one-way source of truth, so UI changes worth keeping must be copied back into `obsidian/config/` by hand. Community plugin code is not vendored, only each plugin's `data.json`.

This repo is public. `workspace.json` / `workspace-mobile.json` / `graph.json` must never be tracked - they leak note paths and titles - and plugin `data.json` files often hold API tokens. Both are enforced by `git/hooks/pre-commit`; never suggest `--no-verify` to get past it.

### Git hooks

`git/hooks/` is tracked and installed via `core.hooksPath` by `run_onchange_after_06-install-git-hooks.sh.tmpl`. Add new hooks there, not to `.git/hooks/`.

`pre-commit` runs `gitleaks git --staged` over the whole staged diff plus the Obsidian-specific rules above. It fails closed when gitleaks is absent, since the Brewfile install is `|| true`-guarded; `DOTFILES_ALLOW_MISSING_GITLEAKS=1` overrides for one commit. Tests: `bash tests/test_precommit_hook.sh`. Two traps when writing fixtures. Assemble token-shaped values at runtime (`printf 'AKIA%s' '...'`) so no literal token pattern is stored in this public repo - otherwise GitHub secret scanning flags it and the hook blocks its own test file. And avoid documented example credentials such as `AKIAIOSFODNN7EXAMPLE`: gitleaks allowlists them, so the test passes for the wrong reason.

The hook is installed per-repo, never globally - a global hook blocking `apiKey` would be unusable in real codebases.

### Git config

`dot_gitconfig.tmpl` generates `~/.gitconfig` with identity from chezmoi data, `[includeIf]` directives for work machines, and an `[include]` pointing to `git/gitconfig` for shared aliases.

### Scripts

| Script | Runs when |
|---|---|
| `run_once_before_01-install-packages.sh.tmpl` | Once (Homebrew/apt packages) |
| `run_once_before_02-install-oh-my-zsh.sh` | Once (Oh My Zsh) |
| `run_onchange_after_nvim-plugins.sh.tmpl` | When any nvim `*.lua` file changes |
| `run_onchange_after_tpm-plugins.sh.tmpl` | When `tmux.conf` changes |
| `run_onchange_after_05-obsidian-config.sh.tmpl` | When any file under `obsidian/` changes |
| `run_onchange_after_06-install-git-hooks.sh.tmpl` | When any file under `git/hooks/` changes |

### Neovim plugins

Managed by [lazy.nvim](https://github.com/folke/lazy.nvim), bootstrapped automatically on first launch. Config is modular: `lua/core/` holds options, keymaps, and autocmds; `lua/plugins/` has one file per plugin (lazy.nvim auto-discovers them via `import`). `lazy-lock.json` is committed to pin plugin versions. After adding a plugin, create a new file in `lua/plugins/` and run `:Lazy sync` inside nvim to update the lockfile.

### Indentation

Neovim defaults to 2-space indentation. The `editorconfig-vim` plugin overrides this per-repo when a `.editorconfig` is present.
