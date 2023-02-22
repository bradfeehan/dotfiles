#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# The root directory of the dotfiles repository (containing this script)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." > /dev/null 2>&1 && pwd -P)"

# Ensure submodule files are present
while read -r file; do
  submodule="$(cut -d/ -f 1-2 <<< "${file}")"
  name="${file##${submodule}/}"
  file="${ROOT}/submodules/${file}"

  if [[ -f "${file}" ]]; then
    debug "Found file '${name}' in submodule '${submodule}'."
  elif [[ "${SPIN:-}" ]]; then
    git submodule update --init --recursive
  else
    echo "File '${name}' missing in submodule '${submodule}'."
    echo 'If git submodules need to be initialised, try:'
    echo
    echo '  $ git submodule update --init --recursive'
    exit 1
  fi
done < "${ROOT}/submodule-files"
