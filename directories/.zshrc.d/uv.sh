if (( ${+commands[uv]} )); then
  eval "$(uv generate-shell-completion bash)"
elif [[ -x "${HOME}/.pyenv/bin/pyenv" ]]; then
  export PYENV_ROOT="${HOME}/.pyenv"
  [[ -d ${PYENV_ROOT}/bin ]] && export PATH="${PYENV_ROOT}/bin:${PATH}"
  PATH="$(bash --norc -ec 'IFS=:; paths=(${PATH});
    for i in ${!paths[@]}; do
      if [[ ${paths[i]} == "''/Users/bfeehan/.pyenv/shims''" ]]; then
        unset '\''paths[i]'\'';
      fi;
    done;
    echo "${paths[*]}"'
  )"

  export PATH="/Users/bfeehan/.pyenv/shims:${PATH}"
  export PYENV_SHELL=zsh
  source '/opt/homebrew/Cellar/pyenv/2.6.20/completions/pyenv.zsh'
  command pyenv rehash
  pyenv() {
    local command=${1:-}
    [ "$#" -gt 0 ] && shift
    case "$command" in
    rehash|shell)
      eval "$(pyenv "sh-$command" "$@")"
      ;;
    *)
      command pyenv "$command" "$@"
      ;;
    esac
  }
fi
