# --- PATH ---
path=(/usr/local/sbin $HOME/.local/bin $HOME/bin $HOME/go/bin $path)
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
setopt GLOB_DOTS

# --- Oh-My-Zsh ---
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""
plugins=(git)

source $ZSH/oh-my-zsh.sh

# --- Prompt (Pure) ---
fpath+="/opt/homebrew/share/zsh/site-functions"
autoload -U promptinit && promptinit
prompt pure

# --- Plugins (Homebrew) ---
export HOMEBREW_NO_ENV_HINTS=1
source "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
source "/opt/homebrew/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
source "/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# --- fzf (fuzzy history search via ctrl+r) ---
if command -v fzf &>/dev/null; then
  source <(fzf --zsh)
fi

# --- Aliases ---
[[ -f "${ZDOTDIR:-$HOME}/.zsh_aliases" ]] && source "${ZDOTDIR:-$HOME}/.zsh_aliases"

# --- Cursor ---
# Restore blinking block before each prompt, so TUI programs (e.g. nvim) that
# emit their own cursor-reset on exit don't leave the cursor in the wrong shape.
_restore_cursor() { printf '\033[1 q' }
add-zsh-hook precmd _restore_cursor

# --- Autocompletions ---
source <(kubectl completion zsh)
source <(minikube completion zsh)

# --- nvm ---
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# --- ripgrep config ---
export RIPGREP_CONFIG_PATH="$HOME/.config/.ripgreprc"

# --- Python pyenv ---
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"

# --- Local overrides ---
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
