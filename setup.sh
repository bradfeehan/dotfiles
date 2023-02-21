#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# The root directory of the dotfiles repository (containing this script)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd -P)"

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
    echo "  git clone --recurse-submodules '${url}' '${root}'"
    echo
    exit 1
  fi

  # Create a pattern to match against the remote's URL
  # The pattern will ensure that GitHub HTTPS remotes are satisfied
  # when they are using an equivalent URL over SSH
  prefix="https://github.com/"
  alternate="git@github.com:"

  if [[ "$url" =~ ^$prefix ]]; then # if URL starts with the prefix
    suffix="${url#$prefix}"
    pattern="^(${prefix}|${alternate})${suffix}\$"
  else
    pattern="^${url}\$"
  fi

  # Check the remote is correct
  actual="$(git -C "${root}" remote get-url "${remote}")"
  if ! [[ "$actual" =~ $pattern ]]; then
    echo "ERROR: Incorrect remote for ${root}"
    echo "--- expected: ${url}"
    echo "+++   actual: ${actual}"
    exit 2
  fi
}

debug() {
  if [[ "$verbose" ]]; then
    echo "$@" >&2
  fi
}

# Arguments
dry_run=
force=
verbose=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-n) dry_run=1;;
    --force|-f) force=1;;
    --verbose|-v) verbose=1;;
    *) echo "Unknown argument: $1"; exit 1;;
  esac
  shift
done

# Enable force-mode in Spin, to overwrite zshrc
if [[ "$SPIN" ]]; then
  force=1
fi

if [[ "$force" ]]; then
  LN=(ln -sfv)
else
  LN=(ln -sv)
fi

if [[ "$dry_run" ]]; then
  LN=(echo "${LN[@]}")
fi

[[ "$dry_run" ]] && debug "--dry-run enabled"
[[ "$force" ]] && debug "--force enabled"

# Directory containing pre-flight checks
checks="$ROOT/checks"

# Directory containing template dotfiles
files="$ROOT/files"

# Directory containing template directories
directories="$ROOT/directories"

# The target directory to place the dotfiles
base_path="$HOME"

# Perform checks
for check_script in "${checks}"/*; do
  debug "Running check: ${check_script##*/}"
  (. "$check_script") && status="$?" || status="$?"
  if [[ "$status" -ne 0 ]]; then
    echo "Check ${check_script##*/} failed (exit status $status)"
    exit 1
  else
    debug "Check ${check_script##*/} passed"
  fi
done

safe_ln() {
  local name="$1" target="$2" destination="$3"

  # Check and make sure it doesn't already exist as a symlink or file
  if [[ -L "$destination" ]]; then
    if [[ "$force" ]]; then
      debug "${name}: Overwriting existing symlink (using --force)"
    else
      debug "${name}: Skipping; this already exists as a symlink"
      return
    fi
  elif [[ -e "$destination" ]]; then
    if [[ "$force" ]]; then
      if [[ -d "$destination" ]]; then
        debug "${name}: Overwriting existing directory (using rmdir)"
        find "$destination" -type f -size 0 -delete
        rmdir "$destination"
      else
        debug "${name}: Overwriting existing file (using --force)"
      fi
    else
      debug "${name}: Skipping; destination is not empty"
      echo "WARNING: the destination is not empty: '${destination}'"
      return
    fi
  fi

  # Do it!
  "${LN[@]}" "$target" "$destination"
}

# Link files
while read -d $'\n' -r dotfile; do
  # debug "Processing dotfile='${dotfile}'"
  target="${files}/${dotfile}"
  destination="${base_path}/${dotfile}"
  directory="${destination%/*}"

  # Ensure containing directory exists
  if [[ ! -d "$directory" ]]; then
    echo "NOTICE: creating directory '$directory'"
    mkdir -p "$directory"
  fi

  safe_ln "${dotfile}" "${target}" "${destination}"
done < <(find "$files" -type f | sed -e "s%${files}\/%%")

# Link directories
while read -d $'\n' -r directory; do
  target="${directories}/${directory}"
  destination="${base_path}/${directory}"

  safe_ln "${directory}" "${target}" "${destination}"
done < <(find "$directories" -mindepth 1 -maxdepth 1 -type d | sed -e "s%${directories}\/%%")

debug "Done"
