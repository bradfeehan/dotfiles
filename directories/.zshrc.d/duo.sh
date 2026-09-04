if [[ -d "${HOME}/src/ZT-trustedpath/ddi" ]]; then
  path+=("${HOME}/src/ZT-trustedpath/ddi")
fi

export DDI_PYENV=true

# Let duo-tsh find a tsh shim that alerts immediately before commands which
# may require a security-key touch. The shim execs the real tsh binary, so its
# terminal, signals, and exit status remain unchanged.
if (( $+commands[duo-tsh] )); then
  function duo-tsh {
    local tsh_wrapper_dir="${HOME}/.local/libexec/duo-tsh"
    local real_tsh="${commands[tsh]:-}"

    if [[ -x "${tsh_wrapper_dir}/tsh" && -n "${real_tsh}" ]]; then
      DUO_TSH_REAL_TSH="${real_tsh}" \
        PATH="${tsh_wrapper_dir}:${PATH}" \
        command duo-tsh "$@"
    else
      command duo-tsh "$@"
    fi
  }
fi
