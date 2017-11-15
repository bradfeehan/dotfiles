#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# The root directory of the dotfiles repository (containing this script)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

check_git_remote() {
  local root="$1"
  local remote="$2"
  local url="$3"

  # Name for errors
  local name="${root##$HOME:~}"

  # Ensure the repository has been cloned
  if ! [[ -d "${root}/.git" ]]; then
    echo "ERROR: ${root} isn't a Git repository"
    echo
    echo "Try this to clone the repository:"
    echo
    echo "  git clone '${url}' '${root}'"
    echo
    exit 1
  fi

  # Check the remote is correct
  actual="$(git -C "${root}" remote get-url "${remote}")"
  if ! [[ "$actual" =~ "$url" ]]; then
    echo "ERROR: Incorrect remote for ${root}"
    echo "--- expected: ${url}"
    echo "+++   actual: ${actual}"
    exit 2
  fi
}

# Directory containing pre-flight checks
checks="$ROOT/checks"

# Directory containing template dotfiles
source="$ROOT/files"

# The target directory to place the dotfiles
base_path="$HOME"

# Perform checks
while read -d $'\0' -r check_script; do
  (. "$check_script") && status="$?" || status="$?"
  if [[ "$status" -ne 0 ]]; then
    echo "Check ${check_script##*/} failed (exit status $status)"
    exit 1
  fi
done < <(find "$checks" -type f -print0)

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

echo "Done"
