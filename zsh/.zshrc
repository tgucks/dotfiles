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
ZSH_DISABLE_COMPFIX=true
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

# --- Aliases ---
[[ -f "${ZDOTDIR:-$HOME}/.zsh_aliases" ]] && source "${ZDOTDIR:-$HOME}/.zsh_aliases"

# --- Cursor ---
# Restore blinking block before each prompt, so TUI programs (e.g. nvim) that
# emit their own cursor-reset on exit don't leave the cursor in the wrong shape.
_restore_cursor() { printf '\033[1 q' }
add-zsh-hook precmd _restore_cursor

# --- Cached shell init ---
# Caches output of slow `source <(cmd ...)` patterns to files.
# Rebuilds automatically when the source binary is updated.
_cache_eval() {
  local name=$1; shift
  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
  local cache_file="$cache_dir/${name}.zsh"
  local cmd_path
  cmd_path="$(command -v "$1" 2>/dev/null)" || return
  if [[ ! -s "$cache_file" || "$cmd_path" -nt "$cache_file" ]]; then
    mkdir -p "$cache_dir"
    "$@" > "$cache_file" 2>/dev/null
  fi
  source "$cache_file"
}

_cache_eval fzf-init fzf --zsh
_cache_eval kubectl-completion kubectl completion zsh
_cache_eval minikube-completion minikube completion zsh

# --- ripgrep config ---
export RIPGREP_CONFIG_PATH="$HOME/.config/.ripgreprc"

# --- Local overrides ---
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
