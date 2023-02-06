if [[ -f "${HOMEBREW_PREFIX:-/usr/local}/share/chnode/chnode.sh" ]]; then
  source "${HOMEBREW_PREFIX:-/usr/local}/share/chnode/chnode.sh"

  if [[ -f "${HOMEBREW_PREFIX:-/usr/local}/share/chnode/auto.sh" ]]; then
    source "${HOMEBREW_PREFIX:-/usr/local}/share/chnode/auto.sh"
    precmd_functions+=(chnode_auto)
  fi
fi

# node-build
if (( ${+commands[node-build]} )); then
  node-install() {
    if [[ $# -gt 1 ]]; then
      echo >&2 "Error: node-install requires zero or one arguments"
      return
    elif [[ $# -eq 0 ]]; then
      node-build --definitions
      return
    fi

    local definition="$1"
    node-build "${definition}" "${HOME}/.nodes/${definition}"
  }
fi
