if [[ -x "${HOMEBREW_PREFIX}/bin/pyenv" ]]; then
  function pyenv {
    LANG=C "${HOMEBREW_PREFIX}/bin/pyenv" "$@"
  }
fi
