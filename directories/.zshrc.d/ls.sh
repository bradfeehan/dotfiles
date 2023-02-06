alias ls="${aliases[ls]:-ls} -F"

if [[ ${(@M)${(f)"$(ls --version 2>&1)"}:#*GNU *} ]]; then
  # GNU Core Utilities

  # Define colors for GNU ls if they're not already defined
  if (( ! $+LS_COLORS )); then
    # Try dircolors when available
    if (( ${+commands[dircolors]} )); then
      eval "$(dircolors --sh $HOME/.dir_colors(.N))"
    else
      export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=36;01:cd=33;01:su=31;40;07:sg=36;40;07:tw=32;40;07:ow=33;40;07:'
    fi
  fi

  alias ls="${aliases[ls]:-ls} --color=auto"
else
  # BSD Core Utilities

  # Define colors for BSD ls if they're not already defined
  if (( ! $+LSCOLORS )); then
      export LSCOLORS='exfxcxdxbxGxDxabagacad'
  fi

  alias ls="${aliases[ls]:-ls} -G"
fi

alias l='ls -1A'         # Lists in one column, hidden files.
alias ll='ls -lh'        # Lists human readable sizes.
alias lr='ll -R'         # Lists human readable sizes, recursively.
alias la='ll -A'         # Lists human readable sizes, hidden files.
alias lm='la | "$PAGER"' # Lists human readable sizes, hidden files through pager.
alias lk='ll -Sr'        # Lists sorted by size, largest last.
alias lt='ll -tr'        # Lists sorted by date, most recent last.
alias lc='lt -c'         # Lists sorted by date, most recent last, shows change time.
alias lu='lt -u'         # Lists sorted by date, most recent last, shows access time.
alias sl='ls'            # Correction for common spelling error.

if [[ ${(@M)${(f)"$(ls --version 2>&1)"}:#*GNU *} ]]; then
  alias lx='ll -XB'      # Lists sorted by extension (GNU only).
fi
