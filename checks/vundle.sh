#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

if ! which 'vim' > /dev/null 2>&1; then
  debug 'Skipping vundle check because vim was not found in $PATH'
else
  check_git_remote "${HOME}/.vim/bundle/Vundle.vim" origin \
    "git@github.com:gmarik/Vundle.vim.git"

  # Ensure Vundle has been installed itself
  if ! [[ -d "${HOME}/.vim/bundle/vundle/.git" ]]; then
    echo "ERROR: Vundle Vim plugin isn't installed"
    echo
    echo "Try fixing it with:"
    echo
    echo "  vim +PluginInstall +qall"
  fi
fi