if [[ -x '/usr/local/bin/pyenv' ]]; then
  function pyenv {
    LANG=C /usr/local/bin/pyenv "$@"
  }
fi
