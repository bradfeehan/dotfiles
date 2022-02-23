if [[ "${HOMEBREW_PREFIX:-}" && -d "${HOMEBREW_PREFIX:-}" ]]; then
  if [[ -f "${HOMEBREW_PREFIX}/share/chnode/chnode.sh" ]]; then
    source "${HOMEBREW_PREFIX}/share/chnode/chnode.sh"

    if [[ -f "${HOMEBREW_PREFIX}/share/chnode/auto.sh" ]]; then
      source "${HOMEBREW_PREFIX}/share/chnode/auto.sh"
      precmd_functions+=(chnode_auto)
    fi
  fi
fi

# node-build
if which node-build > /dev/null 2>&1; then
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
