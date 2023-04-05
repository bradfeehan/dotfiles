if (( $+commands[github-copilot-cli] )); then
  copilot_what-the-shell () {
    TMPFILE="$(mktemp)"
    trap 'rm -f "${TMPFILE}"' EXIT
    if command github-copilot-cli what-the-shell "$@" --shellout "${TMPFILE}"; then
      if [[ -e "${TMPFILE}" ]]; then
        FIXED_CMD="$(cat "${TMPFILE}")"
        print -s "${FIXED_CMD}"
        eval "${FIXED_CMD}"
      else
        printf '%s\n' 'Apologies! Extracting command failed' >&2
      fi
    else
      return 1
    fi
  }

  alias '??'='copilot_what-the-shell'

  copilot_git-assist () {
    TMPFILE=$(mktemp)
    trap 'rm -f "${TMPFILE}"' EXIT
    if command github-copilot-cli git-assist "$@" --shellout "${TMPFILE}"; then
      if [ -e "${TMPFILE}" ]; then
        FIXED_CMD="$(cat "${TMPFILE}")"
        print -s "${FIXED_CMD}"
        eval "${FIXED_CMD}"
      else
        printf '%s\n' 'Apologies! Extracting command failed' >&2
      fi
    else
      return 1
    fi
  }

  alias 'git?'='copilot_git-assist'
  alias 'g?'='copilot_git-assist'

  copilot_gh-assist () {
    TMPFILE=$(mktemp)
    trap 'rm -f "${TMPFILE}"' EXIT
    if command github-copilot-cli gh-assist "$@" --shellout "${TMPFILE}"; then
      if [ -e "${TMPFILE}" ]; then
        FIXED_CMD="$(cat "${TMPFILE}")"
        print -s "${FIXED_CMD}"
        eval "${FIXED_CMD}"
      else
        printf '%s\n' 'Apologies! Extracting command failed' >&2
      fi
    else
      return 1
    fi
  }

  alias 'gh?'='copilot_gh-assist'
  alias 'wts'='copilot_what-the-shell'
fi
