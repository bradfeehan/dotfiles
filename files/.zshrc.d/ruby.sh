if [[ "${HOMEBREW_PREFIX:-}" && -d "${HOMEBREW_PREFIX:-}" ]]; then
  if [[ -f "${HOMEBREW_PREFIX}/share/chruby/chruby.sh" ]]; then
    source "${HOMEBREW_PREFIX}/share/chruby/chruby.sh"

    if [[ -f "${HOMEBREW_PREFIX}/share/chruby/auto.sh" ]]; then
      source "${HOMEBREW_PREFIX}/share/chruby/auto.sh"
    fi
  fi
fi
