# Only sourced by interactive shells

# Load convenience aliases
if [[ -d "${ZDOTDIR:-${HOME}}/.aliases.d" ]]; then
  for file in "${ZDOTDIR:-${HOME}}/.aliases.d"/*; do
    source "${file}"
  done
fi

# Do not overwrite existing files with > and >>. Use >! and >>! to bypass.
unsetopt CLOBBER

# Grep colours configuration
export GREP_COLOR=${GREP_COLOR:-'37;45'}            # BSD.
export GREP_COLORS=${GREP_COLORS:-"mt=$GREP_COLOR"} # GNU.

# Use Dash for viewing man pages if present
if [[ -x '/Applications/Dash.app/Contents/MacOS/Dash' ]]; then
  function man() {
    open "dash://man:$*"
  }
fi

# RubyMine
if [[ -x '/Applications/RubyMine.app/Contents/MacOS/rubymine' ]]; then
  alias mine='/Applications/RubyMine.app/Contents/MacOS/rubymine'
fi

# Pyenv
if [[ -x '/usr/local/bin/pyenv' ]]; then
  function pyenv {
    LANG=C /usr/local/bin/pyenv "$@"
  }
fi

# chruby
if [[ -f /usr/local/share/chruby/chruby.sh ]]; then
  source /usr/local/share/chruby/chruby.sh

  if [[ -f /usr/local/share/chruby/auto.sh ]]; then
    source /usr/local/share/chruby/auto.sh
  fi
fi

# chnode
if [[ -f /usr/local/share/chnode/chnode.sh ]]; then
  source /usr/local/share/chnode/chnode.sh

  if [[ -f /usr/local/share/chnode/auto.sh ]]; then
    source /usr/local/share/chnode/auto.sh
    precmd_functions+=(chnode_auto)
  fi
fi

# node-build
if which node-build > /dev/null 2>&1; then
  node-install() {
    if [[ $# -gt 1 ]]; then
      echo >&2 "Error: node-install requires zero or one arguments"
      return
    elif [[ $# -eq 0 ]]; then
      node-build --definitions
      return
    fi

    local definition="$1"
    node-build "${definition}" "${HOME}/.nodes/${definition}"
  }
fi

# Set up Hub alias ("git" runs "hub")
if [[ -x '/usr/local/bin/hub' ]]; then
  function git {
    /usr/local/bin/hub "$@"
  }
fi

# General-purpose command-line aliases
alias be='bundle exec'
alias fig='docker-compose'
alias tf='terraform'
alias sv='supervisorctl'
alias av='aws-vault-exec-wrapper aws-vault'
alias avws='av aws'
alias avtf='av terraform'
alias ao='aws-vault-exec-wrapper aws-okta'
alias zaws='ao aws'
alias zsm='ao "bundle exec stack_master"'

########################################
## Prezto environment module ###########
########################################

# When pasting, if a URL is detected, escape it automatically
autoload -Uz bracketed-paste-url-magic
zle -N bracketed-paste bracketed-paste-url-magic
autoload -Uz url-quote-magic
zle -N self-insert url-quote-magic

setopt COMBINING_CHARS      # Combine zero-length punctuation characters (accents)
                            # with the base character.
setopt INTERACTIVE_COMMENTS # Enable comments in interactive shell.
setopt RC_QUOTES            # Allow 'Henry''s Garage' instead of 'Henry'\''s Garage'.
unsetopt MAIL_WARNING       # Don't print a warning message if a mail file has been accessed.

# Allow mapping Ctrl+S and Ctrl+Q shortcuts
[[ -n ${TTY:-} && $+commands[stty] == 1 ]] && stty -ixon <$TTY >$TTY

# Jobs
setopt LONG_LIST_JOBS     # List jobs in the long format by default.
setopt AUTO_RESUME        # Attempt to resume existing job before creating a new process.
setopt NOTIFY             # Report status of background jobs immediately.
unsetopt BG_NICE          # Don't run all background jobs at a lower priority.
unsetopt HUP              # Don't kill jobs on shell exit.
unsetopt CHECK_JOBS       # Don't report on jobs when shell exit.

# Termcap
export LESS_TERMCAP_mb=$'\E[01;31m'      # Begins blinking.
export LESS_TERMCAP_md=$'\E[01;31m'      # Begins bold.
export LESS_TERMCAP_me=$'\E[0m'          # Ends mode.
export LESS_TERMCAP_se=$'\E[0m'          # Ends standout-mode.
export LESS_TERMCAP_so=$'\E[00;47;30m'   # Begins standout-mode.
export LESS_TERMCAP_ue=$'\E[0m'          # Ends underline.
export LESS_TERMCAP_us=$'\E[01;32m'      # Begins underline.

########################################
## Prezto editor module  ###############
########################################

# Beep on error in line editor.
setopt BEEP

# Treat these characters as part of a word.
WORDCHARS='*?_-.[]~&;!#$%^(){}<>'

# Use human-friendly identifiers.
zmodload zsh/terminfo
typeset -gA key_info
key_info=(
  'Control'         '\C-'
  'ControlLeft'     '\e[1;5D \e[5D \e\e[D \eOd'
  'ControlRight'    '\e[1;5C \e[5C \e\e[C \eOc'
  'ControlPageUp'   '\e[5;5~'
  'ControlPageDown' '\e[6;5~'
  'Escape'       '\e'
  'Meta'         '\M-'
  'Backspace'    "^?"
  'Delete'       "^[[3~"
  'F1'           "$terminfo[kf1]"
  'F2'           "$terminfo[kf2]"
  'F3'           "$terminfo[kf3]"
  'F4'           "$terminfo[kf4]"
  'F5'           "$terminfo[kf5]"
  'F6'           "$terminfo[kf6]"
  'F7'           "$terminfo[kf7]"
  'F8'           "$terminfo[kf8]"
  'F9'           "$terminfo[kf9]"
  'F10'          "$terminfo[kf10]"
  'F11'          "$terminfo[kf11]"
  'F12'          "$terminfo[kf12]"
  'Insert'       "$terminfo[kich1]"
  'Home'         "$terminfo[khome]"
  'PageUp'       "$terminfo[kpp]"
  'End'          "$terminfo[kend]"
  'PageDown'     "$terminfo[knp]"
  'Up'           "$terminfo[kcuu1]"
  'Left'         "$terminfo[kcub1]"
  'Down'         "$terminfo[kcud1]"
  'Right'        "$terminfo[kcuf1]"
  'BackTab'      "$terminfo[kcbt]"
)

# Set empty $key_info values to an invalid UTF-8 sequence to induce silent
# bindkey failure.
for key in "${(k)key_info[@]}"; do
  if [[ -z "$key_info[$key]" ]]; then
    key_info[$key]='�'
  fi
done

# Functions

# Runs bindkey but for all of the keymaps. Running it with no arguments will
# print out the mappings for all of the keymaps.
function bindkey-all {
  local keymap=''
  for keymap in $(bindkey -l); do
    [[ "$#" -eq 0 ]] && printf "#### %s\n" "${keymap}" 1>&2
    bindkey -M "${keymap}" "$@"
  done
}

# Expands .... to ../..
function expand-dot-to-parent-directory-path {
  if [[ $LBUFFER = *.. ]]; then
    LBUFFER+='/..'
  else
    LBUFFER+='.'
  fi
}
zle -N expand-dot-to-parent-directory-path

# Inserts 'sudo ' at the beginning of the line.
function prepend-sudo {
  if [[ "$BUFFER" != su(do|)\ * ]]; then
    BUFFER="sudo $BUFFER"
    (( CURSOR += 5 ))
  fi
}
zle -N prepend-sudo

# Expand aliases
function glob-alias {
  zle _expand_alias
  zle expand-word
  zle magic-space
}
zle -N glob-alias

# Toggle the comment character at the start of the line. This is meant to work
# around a buggy implementation of pound-insert in zsh.
#
# This is currently only used for the emacs keys because vi-pound-insert has
# been reported to work properly.
function pound-toggle {
  if [[ "$BUFFER" = '#'* ]]; then
    # Because of an oddity in how zsh handles the cursor when the buffer size
    # changes, we need to make this check before we modify the buffer and let
    # zsh handle moving the cursor back if it's past the end of the line.
    if [[ $CURSOR != $#BUFFER ]]; then
      (( CURSOR -= 1 ))
    fi
    BUFFER="${BUFFER:1}"
  else
    BUFFER="#$BUFFER"
    (( CURSOR += 1 ))
  fi
}
zle -N pound-toggle

# Reset to default key bindings.
bindkey -d

for key in "$key_info[Escape]"{B,b} "${(s: :)key_info[ControlLeft]}" \
  "${key_info[Escape]}${key_info[Left]}"
  bindkey -M emacs "$key" emacs-backward-word
for key in "$key_info[Escape]"{F,f} "${(s: :)key_info[ControlRight]}" \
  "${key_info[Escape]}${key_info[Right]}"
  bindkey -M emacs "$key" emacs-forward-word

# Kill to the beginning of the line.
for key in "$key_info[Escape]"{K,k}
  bindkey -M emacs "$key" backward-kill-line

# Redo.
bindkey -M emacs "$key_info[Escape]_" redo

# Search previous character.
bindkey -M emacs "$key_info[Control]X$key_info[Control]B" vi-find-prev-char

# Match bracket.
bindkey -M emacs "$key_info[Control]X$key_info[Control]]" vi-match-bracket

if (( $+widgets[history-incremental-pattern-search-backward] )); then
  bindkey -M emacs "$key_info[Control]R" \
    history-incremental-pattern-search-backward
  bindkey -M emacs "$key_info[Control]S" \
    history-incremental-pattern-search-forward
fi

# Toggle comment at the start of the line. Note that we use pound-toggle which
# is similar to pount insert, but meant to work around some issues that were
# being seen in iTerm.
bindkey -M emacs "$key_info[Escape];" pound-toggle

# Basic keymap
bindkey -M emacs "$key_info[Home]" beginning-of-line
bindkey -M emacs "$key_info[End]" end-of-line

bindkey -M emacs "$key_info[Insert]" overwrite-mode
bindkey -M emacs "$key_info[Delete]" delete-char
bindkey -M emacs "$key_info[Backspace]" backward-delete-char

bindkey -M emacs "$key_info[Left]" backward-char
bindkey -M emacs "$key_info[Right]" forward-char

# Expand history on space.
bindkey -M emacs ' ' magic-space

# Clear screen.
bindkey -M emacs "$key_info[Control]L" clear-screen

# Expand command name to full path.
for key in "$key_info[Escape]"{E,e}
  bindkey -M emacs "$key" expand-cmd-path

# Duplicate the previous word.
for key in "$key_info[Escape]"{M,m}
  bindkey -M emacs "$key" copy-prev-shell-word

# Use a more flexible push-line.
for key in "$key_info[Control]Q" "$key_info[Escape]"{q,Q}
  bindkey -M emacs "$key" push-line-or-edit

unset key

# Bind Shift + Tab to go to the previous menu item.
bindkey -M emacs "$key_info[BackTab]" reverse-menu-complete

# Complete in the middle of word.
bindkey -M emacs "$key_info[Control]I" expand-or-complete

# Expand .... to ../..
bindkey -M emacs "." expand-dot-to-parent-directory-path

# Insert 'sudo ' at the beginning of the line.
bindkey -M emacs "$key_info[Control]X$key_info[Control]S" prepend-sudo

# control-space expands all aliases, including global
bindkey -M emacs "$key_info[Control] " glob-alias

# Do not expand .... to ../.. during incremental search.
bindkey -M isearch . self-insert 2> /dev/null

# Set the key layout.
bindkey -e


########################################
## Load plugins from submodules  #######
########################################

zshrc_path="$(readlink "${HOME}/.zshrc")"
repo_root="$(cd "${zshrc_path%/*}/.." > /dev/null 2>&1 && pwd -P)"

source "${HOME}/.p10k.zsh"
source "${repo_root}/submodules/romkatv/powerlevel10k/powerlevel10k.zsh-theme"
source "${repo_root}/submodules/zsh-users/zsh-completions/zsh-completions.plugin.zsh"
autoload compinit
compinit
source "${repo_root}/submodules/Aloxaf/fzf-tab/fzf-tab.plugin.zsh" # after compinit; before f-sy-h + autosuggestions
source "${repo_root}/submodules/zdharma/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" # after compinit
source "${repo_root}/submodules/zsh-users/zsh-autosuggestions/zsh-autosuggestions.zsh" # after compinit

unset repo_root zshrc_path

# TODO
#  - setting terminal window/tab title
#  - dircolors(1) / LSCOLOR

########################################
## END  ################################
########################################

# BEGIN ZDI
export DOCKER_FOR_MAC_ENABLED=true
if [[ -s "${HOME}/Code/zendesk/zdi/dockmaster/zdi.sh" ]]; then
  source "${HOME}/Code/zendesk/zdi/dockmaster/zdi.sh"
fi
# END ZDI
