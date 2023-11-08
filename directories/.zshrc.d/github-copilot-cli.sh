if ! (( ${+commands[node]} )); then
  printf '%s\n' >&2 'Error configuring GitHub Copilot for CLI: node not found'
elif ! (( ${+commands[npx]} )); then
  printf '%s\n' >&2 'Error configuring GitHub Copilot for CLI: npx not found'
else
  # Node and NPM are available, check if the configuration cache exists
  __copilot_cli_config_cache="${HOME}/.zshrc.local.d/github-copilot-cli.sh"
  if ! [[ -e "${__copilot_cli_config_cache}" ]]; then
    if ! npx --logs-max=0 --no @githubnext/github-copilot-cli -- help >/dev/null 2>&1; then
      # --logs-max=0: without this it creates a debug log on every run (i.e. every time a new terminal window opens)
      #         --no: disables auto-installation
      printf '%s\n' >&2 \
        'Error configuring GitHub Copilot for CLI: package is not installed.' \
        'Use npx to install it:' '' \
        '  npx --yes @githubnext/github-copilot-cli -- help' ''
    else
      # Ensure directory exists
      printf '%s\n' >&2 \
        'Configuring GitHub Copilot for CLI: Creating configuration script (first time setup)...' '' \
        "$ mkdir -p \"${__copilot_cli_config_cache%/*}\""

      if ! mkdir -p "${__copilot_cli_config_cache%/*}"; then
        printf '%s\n' >&2 "Error configuring GitHub Copilot for CLI: mkdir failed: ${__copilot_cli_config_cache%/*}"
      else
        # Create the file
        printf '%s\n' >&2 '' \
          "$ npx @githubnext/github-copilot-cli alias -- \"$0\" > \"${__copilot_cli_config_cache}\""
        if ! npx @githubnext/github-copilot-cli alias -- "$0" > "${__copilot_cli_config_cache}"; then
          printf '%s\n' >&2 'Error configuring GitHub Copilot for CLI: npx @githubnext/github-copilot-cli alias failed'
        fi
      fi
    fi
  fi

  # By now it should definitely already exist or have been created, if not then something went wrong
  if ! [[ -e "${__copilot_cli_config_cache}" ]]; then
    printf '%s\n' >&2 '' \
      'Error configuring GitHub Copilot for CLI: missing cached configuration script' \
      'Expected to be found at:' \
      "  ${__copilot_cli_config_cache}" ''
  else
    . "${__copilot_cli_config_cache}"

    alias github-copilot-cli='npx --logs-max=0 --yes @githubnext/github-copilot-cli --'
    alias copilot=github-copilot-cli
  fi

  unset __copilot_cli_config_cache
fi
