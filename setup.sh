#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# The root directory of the dotfiles repository (containing this script)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Directory containing template dotfiles
source="$ROOT/files"

# The target directory to place the dotfiles
destination="$HOME"

# Complete list of dotfiles
dotfiles="$(find "$source" -type f -print0 | xargs -0 -n1 basename)"

for dotfile in $dotfiles; do
  if [[ ! -L "$destination/$dotfile" ]]; then
    if [[ -e "$destination/$dotfile" ]]; then
      echo "WARNING: the destination is not empty: '$destination/$dotfile'"
    else
      ln -sv "$source/$dotfile" "$destination/$dotfile"
    fi
  fi
done
