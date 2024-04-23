if [[ -z "${PIPXU_HOME}" && -d "${HOME}/.pipxu" ]]; then
  export PIPXU_HOME="${HOME}/.pipxu"
fi

if ! (( $+commands[pipxu] )); then
  function pipxu {
    printf '%s\n' >&2 \
      "pipxu: not found" "Install with:" \
      "  $ curl -LsSf https://raw.githubusercontent.com/bulletmark/pipxu/main/pipxu-bootstrap | sh" \
      "For more info, see https://github.com/bulletmark/pipxu"

    if ! (( $+commands[uv] )); then
      printf '%s\n' >&2 \
        "uv is also missing (required to install pipxu)" \
        "Install with:" "  $ brew install uv" \
        "or:" "  $ curl -LsSf https://astral.sh/uv/install.sh | sh" \
        "For more info, see https://github.com/astral-sh/uv"
    fi

    return 1
  }
fi
