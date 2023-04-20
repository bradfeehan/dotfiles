if [[ -f "${HOMEBREW_PREFIX:-/usr/local}/share/chruby/chruby.sh" ]]; then
  source "${HOMEBREW_PREFIX:-/usr/local}/share/chruby/chruby.sh"

  if [[ -f "${HOMEBREW_PREFIX:-/usr/local}/share/chruby/auto.sh" ]]; then
    source "${HOMEBREW_PREFIX:-/usr/local}/share/chruby/auto.sh"
  fi
fi

alias cop='rubocop'
alias bcop='bundle exec rubocop'
alias becop='bundle exec rubocop'
