#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

if ! which 'vim' > /dev/null 2>&1; then
  debug 'Skipping vundle check because vim was not found in $PATH'
else
  # Ensure Vundle has been installed itself
  if [[ "${SPIN:-}" ]]; then
    git clone --recurse-submodules \
      "https://github.com/bradfeehan/Vundle.vim" \
      "${HOME}/.vim/bundle/Vundle.vim"

    vim +PluginInstall +qall
  else
    check_git_remote "${HOME}/.vim/bundle/Vundle.vim" origin \
      "git@github.com:bradfeehan/Vundle.vim.git"

    if ! [[ -d "${HOME}/.vim/bundle/vundle/.git" ]]; then
      echo "ERROR: Vundle Vim plugin isn't installed"
      echo
      echo "Try fixing it with:"
      echo
      echo "  vim +PluginInstall +qall"
    fi
  fi
fi
