if [[ "$(uname -s)" -eq 'Darwin' && "$(arch)" -eq 'arm64' ]]; then
  intel() {
    if [[ $# -eq 0 ]]; then
      printf '%s\n' >&2 \
        "Usage: $0 <command>" '' \
        'Runs a command with the Intel architecture on an M1 Mac'
      return 127
    fi

    local command=("$@")
    arch -x86_64 env \
      HOMEBREW_PREFIX='/usr/local' \
      HOMEBREW_CELLAR='/usr/local/Cellar' \
      HOMEBREW_REPOSITORY='/usr/local/Homebrew' \
      PATH="/usr/local/bin:/usr/local/sbin${PATH+:$PATH}" \
      MANPATH="/usr/local/share/man${MANPATH+:$MANPATH}:" \
      INFOPATH="/usr/local/share/info:${INFOPATH:-}" \
    zsh -o no_rcs <(\
      printf '%s ' . ; \
      printf '%q\n' "${ZDOTDIR:-${HOME}}/.zprofile" ; \
      printf '%s ' . ; \
      printf '%q\n' "${ZDOTDIR:-${HOME}}/.zshrc" ; \
      printf '%q ' "${command[@]}" ; \
      printf '\n' ; \
    )
  }
fi
