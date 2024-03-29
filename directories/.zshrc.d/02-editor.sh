#
# Prezto editor module
#

# Beep on error in line editor.
setopt BEEP

# Treat these characters as part of a word.
WORDCHARS='*?_-.[]~&;!#$%^(){}<>'

# Expands .... to ../..
function expand-dot-to-parent-directory-path {
  if [[ $LBUFFER = *.. ]]; then
    LBUFFER+='/..'
  else
    LBUFFER+='.'
  fi
}
zle -N expand-dot-to-parent-directory-path

# Expand aliases
function glob-alias {
  zle _expand_alias
  zle expand-word
  zle magic-space
}
zle -N glob-alias

# Expand .... to ../..
bindkey -M emacs "." expand-dot-to-parent-directory-path

# Do not expand .... to ../.. during incremental search.
bindkey -M isearch . self-insert 2> /dev/null

# Set the key layout.
bindkey -e

# Autocomplete settings
builtin bindkey -M emacs '\e[A' up-line-or-search
builtin bindkey -M emacs '\e[B' down-line-or-select

# By default, left and right are equivalent to up and down.
# Instead, this makes either one accept the suggestion.
builtin bindkey -M menuselect '\e[C' accept-line
builtin bindkey -M menuselect '\e[D' accept-line

# Make Enter submit the command line straight from the menu.
# By default, pressing Enter in the menu search exits the search and pressing it otherwise in the menu exits the menu.
bindkey -M menuselect '\r' .accept-line

# Make Ctrl+A and Ctrl+E accept the suggestion before moving to the beginning/end of the line.
# By default, pressing Ctrl+A or Ctrl+E in the menu search does nothing.
bindkey -M menuselect '^A' .accept-line
bindkey -M menuselect '^E' .accept-line
