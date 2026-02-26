# --- PATH ---
path=(/usr/local/sbin $HOME/.local/bin $path)
typeset -U path

# --- Locale ---
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# --- Editor ---
export EDITOR=nvim

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

# --- Prompt (Pure) ---
fpath+="/opt/homebrew/share/zsh/site-functions"
autoload -U promptinit && promptinit
prompt pure

# --- Plugins (Homebrew) ---
source "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
source "/opt/homebrew/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
source "/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
source ~/.oh-my-zsh/plugins/git/git.plugin.zsh

# --- fzf (fuzzy history search via ctrl+r) ---
if command -v fzf &>/dev/null; then
  source <(fzf --zsh)
fi

# --- Aliases ---
[[ -f "${ZDOTDIR:-$HOME}/.zsh_aliases" ]] && source "${ZDOTDIR:-$HOME}/.zsh_aliases"
