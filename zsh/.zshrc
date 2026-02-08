# ~/.zshrc — minimal portable config (machine-specific goes in ~/.zshrc.local)

# --- Homebrew ---
if [[ -d /opt/homebrew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -d /home/linuxbrew/.linuxbrew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# --- PATH ---
path=(/usr/local/sbin $HOME/.local/bin $path)
typeset -U path

# --- Editor ---
export EDITOR=vim

# --- History ---
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS

# --- Options ---
setopt AUTO_CD
setopt CORRECT

# --- Completions ---
autoload -Uz compinit && compinit

# --- Prompt (Pure) ---
autoload -U promptinit && promptinit
prompt pure

# --- Local overrides ---
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
