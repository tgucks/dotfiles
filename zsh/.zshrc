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

# --- Locale ---
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

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

# --- Oh My Zsh ---
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""
plugins=(git)
fpath+="$(brew --prefix)/share/zsh/site-functions"
source "$ZSH/oh-my-zsh.sh"

# --- Prompt (Pure) ---
autoload -U promptinit && promptinit
prompt pure

# --- Plugins (Homebrew) ---
source "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
source "$(brew --prefix)/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
source "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# --- Local overrides ---
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
