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

# Keep the usual history navigation while fzf-tab owns completion selection.
builtin bindkey -M emacs '\e[A' up-line-or-search
builtin bindkey -M emacs '\e[B' down-line-or-history

# Alt+Left/Right word navigation for terminals that send xterm-style modifier
# sequences (e.g. Cursor, VS Code). Terminal.app's "Use Option as Meta key"
# profile sends ^[b / ^[f which zsh binds by default; these cover the CSI form.
bindkey -M emacs '\e[1;3D' backward-word
bindkey -M emacs '\e[1;3C' forward-word
