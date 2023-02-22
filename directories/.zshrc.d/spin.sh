if [[ "${SPIN:-}" ]]; then
  if [[ -e '/etc/zsh/zshrc.default.inc.zsh' ]]; then
    source '/etc/zsh/zshrc.default.inc.zsh'
  fi
fi
