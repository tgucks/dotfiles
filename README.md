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
obsidian/                   -> copied into each opted-in vault (see below)
```

## Claude settings

`dot_claude/modify_settings.json.tmpl` deep-merges managed settings into `~/.claude/settings.json` at apply time. Keys that Claude writes at runtime (e.g., `model`) are preserved. Machine-specific values (API URLs) come from `chezmoi.toml` data.

## Obsidian

Settings only - no notes. Each vault's contents stay wherever you keep them (iCloud, work drive, wherever); this repo only carries the config that makes every vault behave the same.

`run_onchange_after_05-obsidian-config.sh.tmpl` runs `obsidian/apply-obsidian-config.sh`, which reads Obsidian's vault registry (`~/Library/Application Support/obsidian/obsidian.json` on macOS) and copies into every registered vault that holds a `.obsidian-managed` marker file:

```
obsidian/obsidian.vimrc     -> <vault>/.obsidian.vimrc
obsidian/config/            -> <vault>/.obsidian/
```

Tracked under `obsidian/config/`: `app.json`, `core-plugins.json`, `community-plugins.json`, `hotkeys.json`, and per-plugin settings under `plugins/<id>/data.json`. Machine-local state (`workspace.json`, `graph.json`) is deliberately not tracked. The Obsidian Sync toggle is deliberately not managed either - applying it could switch Sync on in a vault governed by someone else's policy.

A vault opts in with a marker file:

```bash
touch <vault>/.obsidian-managed
```

Registered vaults without it are skipped with a message. This keeps a work vault out of reach of an accidental apply.

### Community plugins

Plugin code is **not** vendored - install these by hand from Obsidian's community plugin browser on a new machine:

- `obsidian-vimrc-support` - loads `.obsidian.vimrc`
- `obsidian-relative-line-numbers`

Their settings *are* tracked, so the apply script seeds `plugins/<id>/data.json` before the plugin exists. Installing the plugin afterwards drops `main.js`/`manifest.json` alongside it and keeps the settings. The script prints which plugins are still missing on each run.

### Editing settings

The repo is the source of truth; `chezmoi apply` overwrites vault config with what's committed. If you change something in Obsidian's UI and want to keep it, copy the changed file back into `obsidian/config/` and commit it. Quit Obsidian before applying - it rewrites its config files on exit and will clobber a fresh apply.

That copy-back step is the only way vault data can reach this repo, and **this repo is public**, so it is guarded:

- `.gitignore` excludes `workspace.json`, `workspace-mobile.json` and `graph.json` - they record the paths and titles of your notes.
- `git/hooks/pre-commit` refuses those files even if force-added.

The hook also runs `gitleaks git --staged` over the **whole** staged diff, not just the Obsidian files, so its rules cover every commit to this repo. On top of that it scans any staged `obsidian/config/plugins/*/data.json` for credential-shaped keys (`apiKey`, `accessToken`, `clientSecret`, ...) with a non-empty value - deliberately broader than gitleaks, which matches on the shape of the value and so misses an unrecognised token under an obviously-named key. Plenty of plugins keep API tokens in `data.json`.

## Two GitHub accounts over SSH (work machines)

`~/.gitconfig-personal` rewrites `git@github.com:` to `git@github-personal:`
inside `~/dotfiles` and `~/code/personal`, so personal repos use the personal
key without thinking about it. **That alias is not managed here** - create it
by hand, or personal repos fail with "Could not resolve hostname
github-personal":

```sshconfig
# ~/.ssh/config
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_work
    IdentitiesOnly yes

Host github-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_personal
    IdentitiesOnly yes
```

`IdentitiesOnly yes` matters: without it ssh-agent offers every key and you
authenticate as whoever owns the first one GitHub accepts.

Register each public key with its own account (GitHub rejects the same key on
two accounts), then check which is which:

```bash
ssh -T git@github.com          # -> work account
ssh -T git@github-personal     # -> tgucks
```

Cloning works with a plain `github.com` URL as long as the **destination** is
inside one of those dirs - `includeIf` is evaluated against the new repo's
gitdir, not your current directory. `git clone git@github.com:tgucks/x.git
~/code/personal/x` picks up the personal key; the same clone into `~/work`
does not, whichever directory you run it from.

The rewrite is applied at connection time, so `remote.origin.url` stays
`git@github.com:...` and the repo remains portable to a personal machine.

`gh` is unaffected; it authenticates over HTTPS with its own token
(`gh auth login`, `gh auth switch`).

If gitleaks is missing the hook blocks the commit rather than committing unscanned - the Brewfile install is `|| true`-guarded, so a blocked brew would otherwise silently disable the guard on a public repo. `brew install gitleaks` (in the Brewfile, so a new mac gets it automatically), or `DOTFILES_ALLOW_MISSING_GITLEAKS=1 git commit ...` to skip the scan for one commit.

`tests/test_precommit_hook.sh` covers all of the above in a throwaway repo.

`run_onchange_after_06-install-git-hooks.sh.tmpl` installs the hooks by pointing this repo's `core.hooksPath` at `git/hooks`, so a fresh clone is guarded after the first `chezmoi apply`. To do it by hand: `git -C ~/dotfiles config core.hooksPath git/hooks`.

This is **repo-local, not global** - it only runs for commits in `~/dotfiles` and its worktrees. Nothing is written to `~/.gitconfig`, so your other repos are unaffected.
