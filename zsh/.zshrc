# If you come from bash you might have to change your $PATH.
export PATH=$HOME/.local/bin:$PATH

export ZSH_COMPDUMP=$HOME/.oh-my-zsh/cache/.zcompdump-$HOST
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git
         cp
         ssh
         zsh-syntax-highlighting
         zsh-autosuggestions
         fzf-tab)


# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

alias kssh="kitten ssh"


##################################################
# SSH Agent
##################################################
ssh_agent_setup() {
  emulate -L zsh

  # 1. A reachable agent is already in the environment (forwarded via -A /
  #    ForwardAgent, or inherited). Reuse it and never spawn a local one.
  #    ssh-add exit 2 == cannot reach an agent; 0/1 == reachable.
  if [[ -S "$SSH_AUTH_SOCK" ]]; then
    ssh-add -l &>/dev/null
    (( $? != 2 )) && return
  fi

  # 2. systemd user ssh-agent.socket
  if [[ -S "$XDG_RUNTIME_DIR/ssh-agent.socket" ]]; then
    export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
    return
  fi

  # 3. One persistent per-machine agent, reused across sessions.
  #    The file name carries the hostname so a shared (NFS) $HOME does not
  #    make two machines overwrite each other's env file.
  local rundir="${XDG_RUNTIME_DIR:-$HOME/.local/run}"
  local agent_file="$rundir/ssh-agent.$HOST.env"
  local lock="$rundir/ssh-agent.$HOST.lock"
  mkdir -p "$rundir"

  # Serialize concurrent logins (new shells / tmux panes) so two of them
  # can't both decide to spawn and orphan each other's agent.
  local lock_fd locked=0
  if (( $+commands[flock] )) && exec {lock_fd}>"$lock"; then
    if flock "$lock_fd"; then
      locked=1
    else
      exec {lock_fd}>&-
    fi
  fi

  [[ -r "$agent_file" ]] && source "$agent_file" > /dev/null
  # Same reachability test as step 1. A stale socket file or a reused PID
  # would pass a plain [[ -S ]] / kill -0 check.
  ssh-add -l &>/dev/null
  if (( $? == 2 )); then
    ssh-agent > "$agent_file"
    source "$agent_file" > /dev/null
  fi

  (( locked )) && { flock -u "$lock_fd"; exec {lock_fd}>&-; }
}

ssh_agent_setup

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"


##################################################
# User configuration
##################################################
source $ZSH/oh-my-zsh.sh

export EDITOR='emacsclient'
for _gtagsconf in /usr/share/gtags/gtags.conf \
                  /usr/local/share/gtags/gtags.conf \
                  /opt/homebrew/share/gtags/gtags.conf; do
  [[ -r $_gtagsconf ]] && { export GTAGSCONF=$_gtagsconf; break }
done
unset _gtagsconf
export GTAGSLABEL=native-pygments
export GTAGSOBJDIRPREFIX="$HOME/.cache/gtags"
bindkey -e

setopt nobeep

##################################################
# caps_lock -> ctrl
##################################################

if [[ "$XDG_SESSION_TYPE" == "x11" ]] && command -v setxkbmap &>/dev/null; then
  setxkbmap -option caps:ctrl_modifier
fi

##################################################
# zsh-autosuggestions
##################################################
ZSH_AUTOSUGGEST_ACCEPT_WIDGETS=(
    end-of-line
)
ZSH_AUTOSUGGEST_PARTIAL_ACCEPT_WIDGETS=(
    forward-word
    emacs-forward-word
    forward-char
    emacs-forward-char
)


##################################################
# zsh-syntax-highlight
##################################################

ZSH_HIGHLIGHT_STYLES[default]=fg=cyan
ZSH_HIGHLIGHT_STYLES[suffix-alias]=fg=blue,underline
ZSH_HIGHLIGHT_STYLES[precommand]=fg=blue,underline
ZSH_HIGHLIGHT_STYLES[autodirectory]=fg=blue,underline
ZSH_HIGHLIGHT_STYLES[path]=fg=blue,underline
ZSH_HIGHLIGHT_STYLES[arg0]=fg=blue,bold
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]=fg=cyan,underline
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]=fg=cyan,underline


##################################################
# fzf
##################################################
export FZF_DEFAULT_OPTS_BASE="--height 50% --layout=reverse --border --info=inline --min-height=10 --bind ctrl-b:preview-up,ctrl-f:preview-down,alt-v:half-page-up,ctrl-v:half-page-down,alt-b:preview-half-page-up,alt-f:preview-half-page-down"
export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :100 {}'"
_tree_cmd=exa; (( $+commands[eza] )) && _tree_cmd=eza
export FZF_ALT_C_OPTS="--preview '$_tree_cmd -T -L 2 --color=always {} | head -100'"
unset _tree_cmd

if [ -f /usr/share/fzf/key-bindings.zsh ]; then
  source /usr/share/fzf/key-bindings.zsh
elif (( $+commands[fzf] )); then
  eval "$(fzf --zsh)"
fi
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh


##################################################
# fzf-tab
##################################################

# disable sort when completing `git checkout`
zstyle ':completion:*:git-checkout:*' sort false
# set descriptions format to enable group support
zstyle ':completion:*:descriptions' format '[%d]'
# set list-colors to enable filename colorizing
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# preview directory's content with eza when completing cd
FZF_PREVIEW_CMD='if [ -f $realpath ]; then bat --color=always --style=numbers --line-range=:100 $realpath; else eza -T -L 2 --color=always $realpath; fi'
zstyle ':fzf-tab:complete:cd:*' fzf-preview ${FZF_PREVIEW_CMD}
zstyle ':fzf-tab:complete:ls:*' fzf-preview ${FZF_PREVIEW_CMD}
zstyle ':fzf-tab:complete:exa:*' fzf-preview ${FZF_PREVIEW_CMD}
zstyle ':fzf-tab:complete:eza:*' fzf-preview ${FZF_PREVIEW_CMD}
zstyle ':fzf-tab:complete:cat:*' fzf-preview ${FZF_PREVIEW_CMD}
zstyle ':fzf-tab:complete:bat:*' fzf-preview ${FZF_PREVIEW_CMD}
zstyle ':fzf-tab:*' fzf-pad 10
zstyle ':fzf-tab:*' fzf-bindings 'ctrl-a:toggle-all'
zstyle ':fzf-tab:*' continuous-trigger 'tab'



##################################################
# theme
##################################################
# theme [dark|light], no arg toggles. kitty auto_reload_config picks it up.

THEME_FILE=${XDG_CACHE_HOME:-$HOME/.cache}/theme-mode
THEME_KITTY_CONF=$HOME/.config/kitty/kitty.conf

typeset -gA THEME_FZF_COLORS=(
  light 'light,fg:-1,bg:-1,gutter:#f8f8f8,fg+:#2a2b33,bg+:#e4e4e4,hl:#2f5af3,hl+:#2f5af3,info:#6a6b73,border:#cccccc,prompt:#2f5af3,pointer:#de3d35,marker:#3e953a,spinner:#d2b67b,header:#950095'
  dark  'dark,fg:-1,bg:-1,gutter:#282c34,fg+:#bbc2cf,bg+:#3f444a,hl:#51afef,hl+:#51afef,info:#5B6268,border:#3f444a,prompt:#51afef,pointer:#ff6c6b,marker:#98be65,spinner:#ECBE7B,header:#c678dd'
)
typeset -gA THEME_BAT=( light OneHalfLight dark OneHalfDark )
typeset -gA THEME_COMMENT=( light '#6a6b73' dark '#5B6268' )

theme-show() {
  local m
  if [[ -r $THEME_FILE ]]; then
    m=$(<$THEME_FILE)
    [[ $m == (dark|light) ]] && { print -r -- $m; return }
  fi
  # no state file, fall back to whatever kitty.conf includes
  if grep -q '^include doom_one_light.conf' $THEME_KITTY_CONF 2>/dev/null; then
    print -r -- light
  else
    print -r -- dark
  fi
}

# this shell only, writes nothing
theme-use() {
  local m=$1
  export FZF_COLORS=${THEME_FZF_COLORS[$m]}
  export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS_BASE} --color=${FZF_COLORS}"
  export BAT_THEME=${THEME_BAT[$m]}
  ZSH_HIGHLIGHT_STYLES[comment]=fg=${THEME_COMMENT[$m]},bold
  zstyle ':fzf-tab:*' fzf-flags --color=${FZF_COLORS}
}

theme() {
  local m=$1
  [[ -z $m ]] && { [[ $(theme-show) == dark ]] && m=light || m=dark }
  if [[ $m != (dark|light) ]]; then
    print -u2 -- "theme: want 'dark', 'light', or nothing to toggle"
    return 1
  fi

  # :A resolves the symlink; BSD sed has no --follow-symlinks
  local target=${THEME_KITTY_CONF:A}
  local tmp=${target}.theme.$$
  if [[ $m == dark ]]; then
    sed -e 's|^# *include doom_one\.conf$|include doom_one.conf|' \
        -e 's|^include doom_one_light\.conf$|# include doom_one_light.conf|' \
        $target > $tmp && command mv -f $tmp $target
  else
    sed -e 's|^include doom_one\.conf$|# include doom_one.conf|' \
        -e 's|^# *include doom_one_light\.conf$|include doom_one_light.conf|' \
        $target > $tmp && command mv -f $tmp $target
  fi
  command rm -f $tmp

  mkdir -p ${THEME_FILE:h} && print -r -- $m > $THEME_FILE
  theme-use $m
  print -r -- "theme: $m"
}

theme-use "$(theme-show)"

##################################################
# yazi
##################################################

function y() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
                builtin cd -- "$cwd"
        fi
        rm -f -- "$tmp"
}

# Auto-completion
# ---------------
[[ $- == *i* ]] && source "/usr/share/fzf/completion.zsh" 2> /dev/null


##################################################
# Key-binding
##################################################

bindkey '^T' transpose-chars
bindkey '\ec' capitalize-word
bindkey '\el' down-case-word
bindkey '^x^f' fzf-file-widget # f for file
bindkey '^x^z' fzf-cd-widget # j for jump
bindkey -r "^J"
bindkey -r "^O"

##################################################
# Alias
##################################################

if (( $+commands[eza] )); then
  alias ls="eza -l --icons -s modified"
elif (( $+commands[exa] )); then
  alias ls="exa -l --icons -s modified"
fi

if (( $+commands[bat] )); then
  alias cat="bat"
elif (( $+commands[batcat] )); then
  alias cat="batcat"
fi

clip() {
  if (( $+commands[pbcopy] )); then
    perl -0777 -pe 's/\n\z//' | pbcopy
  elif [ -n "$WAYLAND_DISPLAY" ]; then
    wl-copy --trim-newline
  else
    sed -z 's/\n$//' | xclip -selection clipboard
  fi
}

# opam configuration
[[ ! -r $HOME/.opam/opam-init/init.zsh ]] || source $HOME/.opam/opam-init/init.zsh  > /dev/null 2> /dev/null

# Codon compiler path (added by install script)
[[ -d $HOME/.codon/bin ]] && export PATH=$HOME/.codon/bin:$PATH

export PATH=$HOME/.cabal/bin:$HOME/.ghcup/bin:$PATH

export PATH=$HOME/.cargo/bin:$PATH

export PATH=$HOME/go/bin:$PATH

# uv — Python interpreter manager, venv, and package installer
# Docs: https://docs.astral.sh/uv/
if command -v uv &>/dev/null; then
  eval "$(uv generate-shell-completion zsh)"
  eval "$(uvx --generate-shell-completion zsh)"
fi

command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"
command -v starship &>/dev/null && eval "$(starship init zsh)"

# The next line updates PATH for the Google Cloud SDK.
if [ -f "$HOME/Project/LLCT/docker/google-cloud-sdk/path.zsh.inc" ]; then . "$HOME/Project/LLCT/docker/google-cloud-sdk/path.zsh.inc"; fi

# The next line enables shell command completion for gcloud.
if [ -f "$HOME/Project/LLCT/docker/google-cloud-sdk/completion.zsh.inc" ]; then . "$HOME/Project/LLCT/docker/google-cloud-sdk/completion.zsh.inc"; fi


if [ -d "$HOME/Project/codeql" ]; then export PATH=$HOME/Project/codeql:$PATH; fi
