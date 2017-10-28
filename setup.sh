#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# The root directory of the dotfiles repository (containing this script)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Directory containing template dotfiles
source="$ROOT/files"

# The target directory to place the dotfiles
base_path="$HOME"

# Complete list of dotfiles
dotfiles="$(find "$source" -type f | sed -e "s%${source}\/%%")"

for dotfile in $dotfiles; do
  target="${source}/${dotfile}"
  destination="${base_path}/${dotfile}"
  directory="${destination%/*}"
  if [[ ! -L "$destination" ]]; then  # if not a link (it should be)
    if [[ -e "$destination" ]]; then  # if it already exists
      echo "WARNING: the destination is not empty: '${destination}'"
    else
      # Ensure containing directory exists
      if [[ ! -d "$directory" ]]; then
        echo "NOTICE: creating directory '$directory'"
        mkdir -p "$directory"
      fi
      ln -sv "$target" "$destination"
    fi
  fi
done
